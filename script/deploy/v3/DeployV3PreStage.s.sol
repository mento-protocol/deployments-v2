// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

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

contract DeployV3PreStage is TrebScript, ProxyHelper, PostChecksHelper {
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

    string label = "v3.0.0";

    function setUp() public {
        multisig = sender("multisig").account;

        sortedOracles = lookupProxyWithCodeOrFail("SortedOracles");
        sortedOraclesImpl = lookupWithCodeOrFail("SortedOracles");
        breakerBox = lookupWithCodeOrFail("BreakerBox");
    }

    function postChecks() internal view {
        IOracleAdapter oracleAdapterContract = IOracleAdapter(oracleAdapter);
        IFPMMFactory fpmmFactoryContract = IFPMMFactory(fpmmFactory);
        IRouter routerContract = IRouter(router);
        // Can't use interface because it doesn't have .fallbackPoolFactory getter
        FactoryRegistry factoryRegistryContract = FactoryRegistry(
            factoryRegistry
        );

        // 1. Deployment Verification
        // Verify that contracts are deployed and have code
        lookupWithCodeOrFail("ProxyAdmin");
        lookupWithCodeOrFail("FPMM");
        lookupWithCodeOrFail("OneToOneFPMM");
        lookupWithCodeOrFail("FPMMFactory");
        lookupWithCodeOrFail("MarketHoursBreaker");
        lookupWithCodeOrFail("OracleAdapter");
        lookupWithCodeOrFail("FactoryRegistry");
        lookupWithCodeOrFail("VirtualPoolFactory");
        lookupWithCodeOrFail("Router");
        lookupWithCodeOrFail("SortedOracles");
        lookupWithCodeOrFail("BreakerBox");

        lookupProxyWithCodeOrFail("FPMMFactory");
        lookupProxyWithCodeOrFail("OracleAdapter");
        lookupProxyWithCodeOrFail("FactoryRegistry");
        lookupProxyWithCodeOrFail("SortedOracles");

        // 2. Proxy Implementation Checks
        // Verifies that proxies point to their implementations
        verifyProxyImpl("OracleAdapter", oracleAdapter, oracleAdapterImpl);
        verifyProxyImpl("FPMMFactory", fpmmFactory, fpmmFactoryImpl);
        verifyProxyImpl(
            "FactoryRegistry",
            factoryRegistry,
            factoryRegistryImpl
        );
        verifyProxyImpl("SortedOracles", sortedOracles, sortedOraclesImpl);

        // 3. Proxy Admin Checks
        // Verifies that ProxyAdmin contract is set as admin for each proxy
        verifyProxyAdmin("FPMMFactory", fpmmFactory, proxyAdmin);
        verifyProxyAdmin("OracleAdapter", oracleAdapter, proxyAdmin);
        verifyProxyAdmin("FactoryRegistry", factoryRegistry, proxyAdmin);
        verifyProxyAdmin("SortedOracles", sortedOracles, proxyAdmin);

        // 4. Ownership Checks
        // Verifies that contract owners are set to multisig.
        verifyOwnership("ProxyAdmin", proxyAdmin, multisig);
        verifyOwnership("OracleAdapter", oracleAdapter, multisig);
        verifyOwnership("FPMMFactory", fpmmFactory, multisig);
        verifyOwnership("FactoryRegistry", factoryRegistry, multisig);
        verifyOwnership("VirtualPoolFactory", virtualPoolFactory, multisig);
        verifyOwnership("SortedOracles", sortedOracles, multisig);

        // 5. Implementation Initializer Protection
        // Verifies that implementation contracts cannot be initialized directly (security check).
        verifyInitDisabled("FPMMImpl", fpmmImpl);
        verifyInitDisabled("OneToOneFPMMImpl", oneToOneFpmmImpl);
        verifyInitDisabled("FPMMFactoryImpl", fpmmFactoryImpl);
        verifyInitDisabled("OracleAdapterImpl", oracleAdapterImpl);
        verifyInitDisabled("FactoryRegistryImpl", factoryRegistryImpl);
        verifyCeloInitDisabled("SortedOraclesImpl", sortedOraclesImpl);

        // 6. OracleAdapter Initialization
        // Verifies that OracleAdapter is initialized with correct addresses.
        verifyInit(
            "SortedOracles",
            address(oracleAdapterContract.sortedOracles()),
            sortedOracles
        );
        verifyInit(
            "BreakerBox",
            address(oracleAdapterContract.breakerBox()),
            breakerBox
        );
        verifyInit(
            "MarketHoursBreaker",
            address(oracleAdapterContract.marketHoursBreaker()),
            marketHoursBreaker
        );

        // 7. FPMMFactory Initialization
        // Verifies that FPMMFactory is initialized with the correct addresses.
        verifyInit(
            "OracleAdapter",
            fpmmFactoryContract.oracleAdapter(),
            oracleAdapter
        );
        verifyInit("ProxyAdmin", fpmmFactoryContract.proxyAdmin(), proxyAdmin);
        verifyInit(
            "DefaultImplementation",
            fpmmFactoryContract.registeredImplementations()[0],
            fpmmFactoryImpl
        );
        verifyInit(
            "OneToOneFPMM",
            fpmmFactoryContract.registeredImplementations()[1],
            oneToOneFpmmImpl
        );

        // 8. FPMMFactory Parameters
        // Verifies that FPMMFactory default params are set correctly.
        IFPMM.FPMMParams memory defaultParams = fpmmFactoryContract
            .defaultParams();
        verifyFPMMFactoryParams("lpFee", defaultParams.lpFee, 30);
        verifyFPMMFactoryParams("protocolFee", defaultParams.protocolFee, 0);
        verifyFPMMFactoryParams(
            "protocolFeeRecipient",
            defaultParams.protocolFeeRecipient,
            multisig
        );
        verifyFPMMFactoryParams(
            "rebalanceIncentive",
            defaultParams.rebalanceIncentive,
            50
        );
        verifyFPMMFactoryParams(
            "rebalanceThresholdAbove",
            defaultParams.rebalanceThresholdAbove,
            500
        );
        verifyFPMMFactoryParams(
            "rebalanceThresholdBelow",
            defaultParams.rebalanceThresholdBelow,
            500
        );

        // 9. FPMMFactory Registrations
        // Verifies that_FPMM implementations are registered.
        require(
            fpmmFactoryContract.isRegisteredImplementation(oneToOneFpmmImpl),
            "oneToOneFpmmImpl is not registered"
        );
        require(
            fpmmFactoryContract.isRegisteredImplementation(
                fpmmFactoryContract.registeredImplementations()[0]
            ),
            "defaultFpmmImpl is not registered"
        );

        // 10. FactoryRegistry Initialization
        // Verifies that FactoryRegistry is initialized with correct addresses.
        require(
            factoryRegistryContract.fallbackPoolFactory() == fpmmFactory,
            "Fallback pool factory is not FPMMFactory"
        );

        // 11. FactoryRegistry Approvals
        // Verifies that factories are approved in FactoryRegistry.
        require(
            factoryRegistryContract.isPoolFactoryApproved(virtualPoolFactory),
            "VirtualPoolFactory is not approved in FactoryRegistry"
        );
        require(
            factoryRegistryContract.isPoolFactoryApproved(fpmmFactory),
            "FPMMFactory is not approved in FactoryRegistry"
        );

        // 12. Router Configuration
        // Verifies that the Router is configured correctly.
        require(
            routerContract.factoryRegistry() == factoryRegistry,
            "Router.factoryRegistry does not equal to FactoryRegistry proxy address"
        );
        require(
            routerContract.defaultFactory() == fpmmFactory,
            "Router.defaultFactory does not equal to FPMMFactory proxy address"
        );
    }

    /// @custom:senders deployer,multisig
    function run() public broadcast {
        setUp();

        Senders.Sender storage deployer = sender("multisig");

        proxyAdmin = deployer.create3("ProxyAdmin").setLabel(label).deploy(
            abi.encode(deployer.account)
        );

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

        address sortedOracles = lookupProxyOrFail("SortedOracles");

        address breakerBox = lookup(string.concat("BreakerBox:", label));
        require(
            breakerBox != address(0),
            string.concat(
                "Registry: Lookup failed for BreakerBox in namespace ",
                vm.envOr("NAMESPACE", string("default"))
            )
        );

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
                proxyAdmin
            )
        );

        // TODO: Determine params
        IFPMM.FPMMParams memory params = IFPMM.FPMMParams({
            lpFee: 30,
            protocolFee: 0,
            protocolFeeRecipient: deployer.account,
            rebalanceIncentive: 50,
            rebalanceThresholdAbove: 500,
            rebalanceThresholdBelow: 500
        });

        fpmmFactory = deployProxy(
            deployer,
            "FPMMFactory",
            fpmmFactoryImpl,
            abi.encodeWithSelector(
                IFPMMFactory.initialize.selector,
                oracleAdapter,
                proxyAdmin,
                deployer.account,
                fpmmImpl,
                params
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
                deployer.account
            )
        );

        virtualPoolFactory = deployer
            .create3("VirtualPoolFactory")
            .setLabel(label)
            .deploy(abi.encode(deployer.account));

        IFactoryRegistry factoryRegistryHarness = IFactoryRegistry(
            deployer.harness(factoryRegistry)
        );
        factoryRegistryHarness.approve(virtualPoolFactory);

        router = deployer.create3("Router").setLabel(label).deploy(
            abi.encode(address(0), factoryRegistry, fpmmFactory)
        );
        postChecks();
    }
}
