// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";

contract DeployV3PreStage is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

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

    /// @custom:senders multisig
    function run() public broadcast {
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

        address breakerBox = lookup("BreakerBox");
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
            label,
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
    }
}
