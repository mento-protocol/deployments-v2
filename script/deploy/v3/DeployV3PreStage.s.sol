// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {FactoryRegistry} from "mento-core/swap/FactoryRegistry.sol";
import {FPMMFactory} from "mento-core/swap/FPMMFactory.sol";
import {VirtualPoolFactory} from "mento-core/swap/virtual/VirtualPoolFactory.sol";
import {Router} from "mento-core/swap/router/Router.sol";
import {OracleAdapter} from "mento-core/oracles/OracleAdapter.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";

contract DeployV3PreStage is
    TrebScript,
    AddressbookHelper,
    ProxyHelper,
    PostChecksHelper
{
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address multisig;

    address sortedOracles;
    address sortedOraclesImpl;
    address breakerBox;

    address fpmmImpl;
    address oneToOneFpmmImpl;
    address fpmmFactoryImpl;
    address fpmmFactory;
    address virtualPoolFactory;
    address marketHoursBreaker;
    address oracleAdapterImpl;
    address oracleAdapter;
    address proxyAdmin;
    address factoryRegistryImpl;
    address factoryRegistry;
    address router;
    address reserveV2Impl;
    address reserveV2;
    address stableTokenV3Impl;
    address reserveLiquidityStrategyImpl;
    address reserveLiquidityStrategy;
    IMentoConfig config;

    string constant label = "v3.0.0";

    function setUp() public {
        multisig = lookupAddressbook("MigrationMultisig");

        sortedOracles = lookupProxyWithCodeOrFail("SortedOracles");
        sortedOraclesImpl = lookupWithCodeOrFail("SortedOracles:v2.6.5");
        breakerBox = lookupWithCodeOrFail("BreakerBox:v2.6.5");
        proxyAdmin = lookupWithCodeOrFail("ProxyAdmin");
        config = Config.get();
    }

    /// @custom:senders deployer
    function run() public broadcast {
        setUp();

        Senders.Sender storage deployer = sender("deployer");

        fpmmImpl = deployer.create3("FPMM").setLabel(label).deploy(
            abi.encode(true)
        );

        oneToOneFpmmImpl = deployer
            .create3("OneToOneFPMM")
            .setLabel(label)
            .deploy(abi.encode(true));

        fpmmFactoryImpl = deployer
            .create3("FPMMFactory")
            .setLabel(label)
            .deploy(abi.encode(true));

        marketHoursBreaker = deployer
            .create3("MarketHoursBreaker")
            .setLabel(label)
            .deploy();

        oracleAdapterImpl = deployer
            .create3("OracleAdapter")
            .setLabel(label)
            .deploy(abi.encode(true));

        oracleAdapter = deployProxy(
            deployer,
            "OracleAdapter",
            oracleAdapterImpl,
            abi.encodeWithSelector(
                IOracleAdapter.initialize.selector,
                sortedOracles,
                breakerBox,
                marketHoursBreaker,
                address(0),
                multisig
            )
        );

        fpmmFactory = deployProxy(
            deployer,
            "FPMMFactory",
            fpmmFactoryImpl,
            abi.encodeWithSelector(
                IFPMMFactory.initialize.selector,
                oracleAdapter,
                proxyAdmin,
                multisig,
                fpmmImpl,
                config.getDefaultFPMMParams()
            )
        );

        IFPMMFactory fpmmFactoryHarness = IFPMMFactory(
            deployer.harness(fpmmFactory)
        );
        fpmmFactoryHarness.registerFPMMImplementation(oneToOneFpmmImpl);

        factoryRegistryImpl = deployer
            .create3("FactoryRegistry")
            .setLabel(label)
            .deploy(abi.encode(true));

        factoryRegistry = deployProxy(
            deployer,
            "FactoryRegistry",
            factoryRegistryImpl,
            abi.encodeWithSelector(
                IFactoryRegistry.initialize.selector,
                fpmmFactory,
                multisig
            )
        );

        virtualPoolFactory = deployer
            .create3("VirtualPoolFactory")
            .setLabel(label)
            .deploy(abi.encode(multisig));

        IFactoryRegistry factoryRegistryHarness = IFactoryRegistry(
            deployer.harness(factoryRegistry)
        );
        factoryRegistryHarness.approve(virtualPoolFactory);

        router = deployer.create3("Router").setLabel(label).deploy(
            abi.encode(address(0), factoryRegistry, fpmmFactory)
        );

        reserveV2Impl = deployer.create3("ReserveV2").setLabel(label).deploy(
            abi.encode(true)
        );

        address[] memory empty = new address[](0);
        reserveV2 = deployProxy(
            deployer,
            "ReserveV2",
            reserveV2Impl,
            abi.encodeWithSelector(
                IReserveV2.initialize.selector,
                empty,
                empty,
                empty,
                empty,
                empty,
                multisig
            )
        );

        stableTokenV3Impl = deployer
            .create3("StableTokenV3")
            .setLabel(label)
            .deploy(abi.encode(true));

        reserveLiquidityStrategyImpl = deployer
            .create3("ReserveLiquidityStrategy")
            .setLabel(label)
            .deploy(abi.encode(true));

        reserveLiquidityStrategy = deployProxy(
            deployer,
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategyImpl,
            abi.encodeWithSelector(
                IReserveLiquidityStrategy.initialize.selector,
                multisig,
                reserveV2
            )
        );

        postChecks();
    }

    function postChecks() internal view {
        IOracleAdapter oracleAdapterContract = IOracleAdapter(oracleAdapter);
        IFPMMFactory fpmmFactoryContract = IFPMMFactory(fpmmFactory);
        IRouter routerContract = IRouter(router);
        // Can't use interface because it doesn't have .fallbackPoolFactory getter
        FactoryRegistry factoryRegistryContract = FactoryRegistry(
            factoryRegistry
        );

        // Proxy Implementation Checks
        // Verifies that proxies point to their implementations
        verifyProxyImpl("OracleAdapter", oracleAdapter, oracleAdapterImpl);
        verifyProxyImpl("FPMMFactory", fpmmFactory, fpmmFactoryImpl);
        verifyProxyImpl(
            "FactoryRegistry",
            factoryRegistry,
            factoryRegistryImpl
        );
        verifyProxyImpl("reserveV2", reserveV2, reserveV2Impl);
        verifyProxyImpl(
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategy,
            reserveLiquidityStrategyImpl
        );

        // Proxy Admin Checks
        // Verifies that ProxyAdmin contract is set as admin for each proxy
        verifyProxyAdmin("FPMMFactory", fpmmFactory);
        verifyProxyAdmin("OracleAdapter", oracleAdapter);
        verifyProxyAdmin("FactoryRegistry", factoryRegistry);
        verifyProxyAdmin("ReserveV2", reserveV2);
        verifyProxyAdmin("ReserveLiquidityStrategy", reserveLiquidityStrategy);

        // Ownership Checks
        // Verifies that contract owners are set to multisig.
        verifyOwnership("OracleAdapter", oracleAdapter, multisig);
        verifyOwnership("FPMMFactory", fpmmFactory, multisig);
        verifyOwnership("FactoryRegistry", factoryRegistry, multisig);
        verifyOwnership("VirtualPoolFactory", virtualPoolFactory, multisig);
        verifyOwnership("ReserveV2", reserveV2, multisig);
        verifyOwnership(
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategy,
            multisig
        );

        // Implementation Initializer Protection
        // Verifies that implementation contracts cannot be initialized directly (security check).
        verifyInitDisabled("FPMMImpl", fpmmImpl);
        verifyInitDisabled("OneToOneFPMMImpl", oneToOneFpmmImpl);
        verifyInitDisabled("FPMMFactoryImpl", fpmmFactoryImpl);
        verifyInitDisabled("OracleAdapterImpl", oracleAdapterImpl);
        verifyInitDisabled("FactoryRegistryImpl", factoryRegistryImpl);
        verifyInitDisabled("ReserveV2Impl", reserveV2Impl);
        verifyInitDisabled("StableTokenV3Impl", stableTokenV3Impl);
        verifyInitDisabled(
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategyImpl
        );

        // OracleAdapter Initialization
        // Verifies that OracleAdapter is initialized with correct addresses.
        require(
            address(oracleAdapterContract.sortedOracles()) == sortedOracles,
            "SortedOracles initialized with mismatched address"
        );
        require(
            address(oracleAdapterContract.breakerBox()) == breakerBox,
            "BreakerBox initialized with mismatched address"
        );
        require(
            address(oracleAdapterContract.marketHoursBreaker()) ==
                marketHoursBreaker,
            "MarketHoursBreaker initialized with mismatched address"
        );

        // FPMMFactory Initialization
        // Verifies that FPMMFactory is initialized with the correct addresses.
        require(
            address(fpmmFactoryContract.oracleAdapter()) == oracleAdapter,
            "OracleAdapter initialized with mismatched address"
        );
        require(
            address(fpmmFactoryContract.proxyAdmin()) == proxyAdmin,
            "ProxyAdmin initialized with mismatched address"
        );

        // FPMMFactory Parameters
        // Verifies that FPMMFactory default params are set correctly.
        IFPMM.FPMMParams memory defaultParams = fpmmFactoryContract
            .defaultParams();

        require(defaultParams.lpFee == 30, "lpFee param mismatched");
        require(defaultParams.protocolFee == 0, "protocolFee param mismatched");
        require(
            defaultParams.protocolFeeRecipient == multisig,
            "protocolFeeRecipient param mismatched"
        );
        require(
            defaultParams.rebalanceIncentive == 50,
            "rebalanceIncentive param mismatched"
        );
        require(
            defaultParams.rebalanceThresholdAbove == 500,
            "rebalanceThresholdAbove param mismatched"
        );
        require(
            defaultParams.rebalanceThresholdBelow == 500,
            "rebalanceThresholdBelow param mismatched"
        );

        // FPMMFactory Registrations
        // Verifies that_FPMM implementations are registered.
        require(
            fpmmFactoryContract.isRegisteredImplementation(oneToOneFpmmImpl),
            "oneToOneFpmmImpl is not registered"
        );
        require(
            fpmmFactoryContract.isRegisteredImplementation(fpmmImpl),
            "defaultFpmmImpl is not registered"
        );

        // FactoryRegistry Initialization
        // Verifies that FactoryRegistry is initialized with correct addresses.
        require(
            factoryRegistryContract.fallbackPoolFactory() == fpmmFactory,
            "Fallback pool factory is not FPMMFactory"
        );

        // FactoryRegistry Approvals
        // Verifies that factories are approved in FactoryRegistry.
        require(
            factoryRegistryContract.isPoolFactoryApproved(fpmmFactory),
            "FPMMFactory is not approved in FactoryRegistry"
        );

        // Router Configuration
        // Verifies that the Router is configured correctly.
        require(
            routerContract.factoryRegistry() == factoryRegistry,
            "Router.factoryRegistry does not equal to FactoryRegistry proxy address"
        );
        require(
            routerContract.defaultFactory() == fpmmFactory,
            "Router.defaultFactory does not equal to FPMMFactory proxy address"
        );

        // ReserveLiquidityStrategy's Reserve is ReserveV2
        require(
            reserveLiquidityStrategy.reserve() == reserveV2,
            "ReserveLiquidityStrategy.reserve does not equal to Reserve proxy address"
        );
    }
}
