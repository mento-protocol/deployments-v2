// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";

contract DeployV3PreStage is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address owner;
    address feeSetter;
    address protocolFeeRecipient;

    address sortedOracles;
    address breakerBox;

    address fpmmImpl;
    address fpmmFactoryImpl;
    address fpmmFactory;
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
    address l2SequencerUptimeFeed;
    IMentoConfig config;

    string constant label = "v3.0.0";

    function setUp() public {
        config = Config.get();

        sortedOracles = lookupProxyOrFail("SortedOracles");
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        proxyAdmin = lookupOrFail("ProxyAdmin");
        feeSetter = lookupOrFail("FeeSetter");
        protocolFeeRecipient = lookupOrFail("ProtocolFeeRecipient");
        l2SequencerUptimeFeed = lookup("L2SequencerUptimeFeed");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        owner = sender("migrationOwner").account;

        fpmmImpl = deployer.create3("FPMM").setLabel(label).deploy(abi.encode(true));

        fpmmFactoryImpl = deployer.create3("FPMMFactory").setLabel(label).deploy(abi.encode(true));

        marketHoursBreaker = _deployMarketHoursBreaker(deployer);

        oracleAdapterImpl = deployer.create3("OracleAdapter").setLabel(label).deploy(abi.encode(true));

        oracleAdapter = deployProxy(
            deployer,
            "OracleAdapter",
            oracleAdapterImpl,
            abi.encodeWithSelector(
                IOracleAdapter.initialize.selector,
                sortedOracles,
                breakerBox,
                marketHoursBreaker,
                l2SequencerUptimeFeed,
                owner
            )
        );

        IFPMM.FPMMParams memory params = config.getDefaultFPMMParams();
        require(params.lpFee > 0 || params.protocolFee > 0, "fees not set for default FPMM params");
        require(params.protocolFeeRecipient != address(0), "protocolFeeRecipient not set for default FPMM params");
        require(params.rebalanceIncentive > 0, "rebalanceIncentive not set for default FPMM params");
        require(params.rebalanceThresholdAbove > 0, "rebalanceThresholdAbove not set for default FPMM params");
        require(params.rebalanceThresholdBelow > 0, "rebalanceThresholdBelow not set for default FPMM params");
        params.feeSetter = feeSetter;
        params.protocolFeeRecipient = protocolFeeRecipient;

        fpmmFactory = deployProxy(
            deployer,
            "FPMMFactory",
            fpmmFactoryImpl,
            abi.encodeWithSelector(IFPMMFactory.initialize.selector, oracleAdapter, proxyAdmin, owner, fpmmImpl, params)
        );

        factoryRegistryImpl = deployer.create3("FactoryRegistry").setLabel(label).deploy(abi.encode(true));

        factoryRegistry = deployProxy(
            deployer,
            "FactoryRegistry",
            factoryRegistryImpl,
            abi.encodeWithSelector(IFactoryRegistry.initialize.selector, fpmmFactory, deployer.account)
        );

        IOwnable factoryRegistryOwnable = IOwnable(deployer.harness(factoryRegistry));
        factoryRegistryOwnable.transferOwnership(owner);

        router = deployer.create3("Router").setLabel(label).deploy(abi.encode(address(0), factoryRegistry, fpmmFactory));

        reserveV2Impl = deployer.create3("ReserveV2").setLabel(label).deploy(abi.encode(true));

        address[] memory empty = new address[](0);
        reserveV2 = deployProxy(
            deployer,
            "ReserveV2",
            reserveV2Impl,
            abi.encodeWithSelector(IReserveV2.initialize.selector, empty, empty, empty, empty, empty, owner)
        );

        stableTokenV3Impl = deployer.create3("StableTokenV3").setLabel(label).deploy(abi.encode(true));

        // Hardcoded label for consistency with seploia when running this on mainnet
        reserveLiquidityStrategyImpl =
            deployer.create3("ReserveLiquidityStrategy").setLabel("v3.0.1").deploy(abi.encode(true));

        reserveLiquidityStrategy = deployProxy(
            deployer,
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategyImpl,
            abi.encodeWithSelector(IReserveLiquidityStrategy.initialize.selector, owner, reserveV2)
        );

        postChecks();
    }

    function postChecks() internal view {
        IOracleAdapter oracleAdapterContract = IOracleAdapter(oracleAdapter);
        IFPMMFactory fpmmFactoryContract = IFPMMFactory(fpmmFactory);
        IRouter routerContract = IRouter(router);
        IFactoryRegistry factoryRegistryContract = IFactoryRegistry(factoryRegistry);
        IReserveLiquidityStrategy reserveLiquidityStrategyContract = IReserveLiquidityStrategy(reserveLiquidityStrategy);

        // Proxy Implementation Checks
        // Verifies that proxies point to their implementations
        verifyProxyImpl("OracleAdapter", oracleAdapter, oracleAdapterImpl);
        verifyProxyImpl("FPMMFactory", fpmmFactory, fpmmFactoryImpl);
        verifyProxyImpl("FactoryRegistry", factoryRegistry, factoryRegistryImpl);
        verifyProxyImpl("reserveV2", reserveV2, reserveV2Impl);
        verifyProxyImpl("ReserveLiquidityStrategy", reserveLiquidityStrategy, reserveLiquidityStrategyImpl);

        // Ownership Checks
        // Verifies that contract owners are set to multisig.
        verifyOwnership("OracleAdapter", oracleAdapter, owner);
        verifyOwnership("FPMMFactory", fpmmFactory, owner);
        verifyOwnership("FactoryRegistry", factoryRegistry, owner);
        verifyOwnership("ReserveV2", reserveV2, owner);
        verifyOwnership("ReserveLiquidityStrategy", reserveLiquidityStrategy, owner);

        // Implementation Initializer Protection
        // Verifies that implementation contracts cannot be initialized directly (security check).
        verifyInitDisabled("FPMMImpl", fpmmImpl);
        verifyInitDisabled("FPMMFactoryImpl", fpmmFactoryImpl);
        verifyInitDisabled("OracleAdapterImpl", oracleAdapterImpl);
        verifyInitDisabled("FactoryRegistryImpl", factoryRegistryImpl);
        verifyInitDisabled("ReserveV2Impl", reserveV2Impl);
        verifyInitDisabled("StableTokenV3Impl", stableTokenV3Impl);
        verifyInitDisabled("ReserveLiquidityStrategy", reserveLiquidityStrategyImpl);

        // OracleAdapter Initialization
        // Verifies that OracleAdapter is initialized with correct addresses.
        require(
            address(oracleAdapterContract.sortedOracles()) == sortedOracles,
            "SortedOracles initialized with mismatched address"
        );
        require(
            address(oracleAdapterContract.breakerBox()) == breakerBox, "BreakerBox initialized with mismatched address"
        );
        require(
            address(oracleAdapterContract.marketHoursBreaker()) == marketHoursBreaker,
            "MarketHoursBreaker initialized with mismatched address"
        );
        require(
            address(oracleAdapterContract.l2SequencerUptimeFeed()) == l2SequencerUptimeFeed,
            "L2SequencerUptimeFeed initialized with mismatched address"
        );

        // FPMMFactory Initialization
        // Verifies that FPMMFactory is initialized with the correct addresses.
        require(
            address(fpmmFactoryContract.oracleAdapter()) == oracleAdapter,
            "OracleAdapter initialized with mismatched address"
        );
        require(
            address(fpmmFactoryContract.proxyAdmin()) == proxyAdmin, "ProxyAdmin initialized with mismatched address"
        );

        // FPMMFactory Parameters
        // Verifies that FPMMFactory default params are set correctly.
        IFPMM.FPMMParams memory defaultParams = fpmmFactoryContract.defaultParams();

        IFPMM.FPMMParams memory expected = config.getDefaultFPMMParams();

        require(defaultParams.lpFee == expected.lpFee, "lpFee param mismatch");
        require(defaultParams.protocolFee == expected.protocolFee, "protocolFee param mismatch");
        require(defaultParams.protocolFeeRecipient == protocolFeeRecipient, "protocolFeeRecipient param mismatch");
        require(defaultParams.feeSetter == feeSetter, "feeSetter param mismatch");
        require(defaultParams.rebalanceIncentive == expected.rebalanceIncentive, "rebalanceIncentive param mismatch");
        require(
            defaultParams.rebalanceThresholdAbove == expected.rebalanceThresholdAbove,
            "rebalanceThresholdAbove param mismatch"
        );
        require(
            defaultParams.rebalanceThresholdBelow == expected.rebalanceThresholdBelow,
            "rebalanceThresholdBelow param mismatch"
        );

        // FPMMFactory Registrations
        // Verifies that the FPMM implementation is registered.
        require(fpmmFactoryContract.isRegisteredImplementation(fpmmImpl), "defaultFpmmImpl is not registered");

        // FactoryRegistry Initialization
        // Verifies that FactoryRegistry is initialized with correct addresses.
        require(
            factoryRegistryContract.fallbackPoolFactory() == fpmmFactory, "Fallback pool factory is not FPMMFactory"
        );

        // FactoryRegistry Approvals
        // Verifies that factories are approved in FactoryRegistry.
        require(
            factoryRegistryContract.isPoolFactoryApproved(fpmmFactory), "FPMMFactory is not approved in FactoryRegistry"
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
            address(reserveLiquidityStrategyContract.reserve()) == reserveV2,
            "ReserveLiquidityStrategy.reserve does not equal to Reserve proxy address"
        );
    }

    function _deployMarketHoursBreaker(Senders.Sender storage deployer) internal returns (address) {
        bool toggleable = vm.envOr("MARKET_HOURS_BREAKER_TOGGLEABLE", false);
        if (toggleable) {
            return deployer.create3("MarketHoursBreakerToggleable").setLabel(label).deploy(abi.encode(deployer.account));
        }
        return deployer.create3("MarketHoursBreaker").setLabel(label).deploy();
    }
}
