// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";

contract DeployV3PreStage2 is
    TrebScript,
    ProxyHelper,
    PostChecksHelper
{
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address owner;

    address fpmmFactory;
    address factoryRegistry;
    address virtualPoolFactory;
    address router;
    address reserveV2Impl;
    address reserveV2;
    address stableTokenV3Impl;
    address reserveLiquidityStrategyImpl;
    address reserveLiquidityStrategy;

    string constant label = "v3.0.0";

    function setUp() public {
        // Read Phase 1 deployments from registry
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        factoryRegistry = lookupProxyOrFail("FactoryRegistry");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        owner = sender("migrationOwner").account;

        virtualPoolFactory = deployer
            .create3("VirtualPoolFactory")
            .setLabel(label)
            .deploy(abi.encode(owner));

        IFactoryRegistry factoryRegistryHarness = IFactoryRegistry(
            deployer.harness(factoryRegistry)
        );
        IOwnable factoryRegistryOwnable = IOwnable(
            deployer.harness(factoryRegistry)
        );
        factoryRegistryHarness.approve(virtualPoolFactory);
        factoryRegistryOwnable.transferOwnership(owner);

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
                owner
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
                owner,
                reserveV2
            )
        );

        postChecks();
    }

    function postChecks() internal view {
        IFactoryRegistry factoryRegistryContract = IFactoryRegistry(
            factoryRegistry
        );
        IRouter routerContract = IRouter(router);
        IReserveLiquidityStrategy reserveLiquidityStrategyContract = IReserveLiquidityStrategy(
                reserveLiquidityStrategy
            );

        // Proxy Implementation Checks
        verifyProxyImpl("ReserveV2", reserveV2, reserveV2Impl);
        verifyProxyImpl(
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategy,
            reserveLiquidityStrategyImpl
        );

        // Ownership Checks
        verifyOwnership("FactoryRegistry", factoryRegistry, owner);
        verifyOwnership("VirtualPoolFactory", virtualPoolFactory, owner);
        verifyOwnership("ReserveV2", reserveV2, owner);
        verifyOwnership(
            "ReserveLiquidityStrategy",
            reserveLiquidityStrategy,
            owner
        );

        // Implementation Initializer Protection
        verifyInitDisabled("ReserveV2Impl", reserveV2Impl);
        verifyInitDisabled("StableTokenV3Impl", stableTokenV3Impl);
        verifyInitDisabled(
            "ReserveLiquidityStrategyImpl",
            reserveLiquidityStrategyImpl
        );

        // FactoryRegistry Approvals
        require(
            factoryRegistryContract.isPoolFactoryApproved(fpmmFactory),
            "FPMMFactory is not approved in FactoryRegistry"
        );

        // Router Configuration
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
}
