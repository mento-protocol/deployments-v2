// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console2 as console} from "forge-std/console2.sol";

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";

/// @title RedeployRouterPolygon
/// @notice Redeploys the Router on Polygon with the correct constructor arguments.
/// @dev The original Router (label v3.0.0) was deployed in the second half of a split
///      DeployV3PreStage run, where the in-memory `factoryRegistry` and `fpmmFactory`
///      variables were address(0) because the first half of the script was commented out.
///      Since both are immutables on the Router, the only fix is a fresh deployment.
///      A new label (v3.0.1) is required because create3 salts are derived from
///      namespace/artifact:label and the v3.0.0 address is already occupied.
contract RedeployRouterPolygon is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address fpmmFactory;
    address factoryRegistry;
    address brokenRouter;
    address router;

    string constant NEW_LABEL = "v3.0.1";
    string constant OLD_ROUTER_IDENTIFIER = "Router:v3.0.0";

    function setUp() public {
        // Resolve both dependencies via proxy lookups — no hardcoded addresses.
        fpmmFactory = lookupProxyWithCodeOrFail("FPMMFactory");
        factoryRegistry = lookupProxyWithCodeOrFail("FactoryRegistry");
        brokenRouter = lookup(OLD_ROUTER_IDENTIFIER);
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        console.log("=== RedeployRouterPolygon ===");
        console.log("FPMMFactory (proxy lookup):    ", fpmmFactory);
        console.log("FactoryRegistry (proxy lookup):", factoryRegistry);

        logBrokenRouterState();
        preChecks();

        console.log("");
        console.log("Deploying Router with label", NEW_LABEL);
        console.log("  constructor arg _forwarder:      ", address(0));
        console.log("  constructor arg _factoryRegistry:", factoryRegistry);
        console.log("  constructor arg _factory:        ", fpmmFactory);

        router =
            deployer.create3("Router").setLabel(NEW_LABEL).deploy(abi.encode(address(0), factoryRegistry, fpmmFactory));

        console.log("Router deployed at:", router);

        postChecks();
    }

    /// @notice Logs the state of the broken v3.0.0 Router for the record.
    function logBrokenRouterState() internal view {
        console.log("");
        if (brokenRouter == address(0)) {
            console.log("Old Router (v3.0.0) not found in registry, skipping state log");
            return;
        }
        IRouter broken = IRouter(brokenRouter);
        console.log("Old (broken) Router:", brokenRouter);
        console.log("  factoryRegistry:", broken.factoryRegistry());
        console.log("  defaultFactory: ", broken.defaultFactory());
        if (broken.factoryRegistry() != address(0) || broken.defaultFactory() != address(0)) {
            console.log("  WARNING: old Router vars are NOT zero - double check a redeploy is actually needed");
        }
    }

    /// @notice Sanity checks on the dependencies before spending gas on the deployment.
    function preChecks() internal view {
        console.log("");
        console.log("--- Pre-checks ---");

        IFactoryRegistry factoryRegistryContract = IFactoryRegistry(factoryRegistry);

        require(
            factoryRegistryContract.fallbackPoolFactory() == fpmmFactory,
            "PRE-CHECK FAILED: FactoryRegistry.fallbackPoolFactory is not the FPMMFactory proxy"
        );
        console.log("[OK] FactoryRegistry.fallbackPoolFactory == FPMMFactory");

        require(
            factoryRegistryContract.isPoolFactoryApproved(fpmmFactory),
            "PRE-CHECK FAILED: FPMMFactory is not approved in FactoryRegistry"
        );
        console.log("[OK] FPMMFactory is approved in FactoryRegistry");
    }

    /// @notice Verifies the freshly deployed Router is wired to the correct contracts.
    function postChecks() internal view {
        console.log("");
        console.log("--- Post-checks ---");

        require(router != address(0), "POST-CHECK FAILED: Router address is zero");
        require(router.code.length > 0, "POST-CHECK FAILED: Router has no code");
        console.log("[OK] Router has code at", router);

        require(router != brokenRouter, "POST-CHECK FAILED: new Router address equals the broken v3.0.0 Router");
        console.log("[OK] Router address differs from broken v3.0.0 Router");

        IRouter routerContract = IRouter(router);
        address actualFactoryRegistry = routerContract.factoryRegistry();
        address actualDefaultFactory = routerContract.defaultFactory();

        console.log("Router.factoryRegistry:", actualFactoryRegistry);
        console.log("Router.defaultFactory: ", actualDefaultFactory);

        require(actualFactoryRegistry != address(0), "POST-CHECK FAILED: Router.factoryRegistry is zero");
        require(actualDefaultFactory != address(0), "POST-CHECK FAILED: Router.defaultFactory is zero");
        require(
            actualFactoryRegistry == factoryRegistry,
            "POST-CHECK FAILED: Router.factoryRegistry does not equal the FactoryRegistry proxy"
        );
        console.log("[OK] Router.factoryRegistry == FactoryRegistry proxy");

        require(
            actualDefaultFactory == fpmmFactory,
            "POST-CHECK FAILED: Router.defaultFactory does not equal the FPMMFactory proxy"
        );
        console.log("[OK] Router.defaultFactory == FPMMFactory proxy");

        console.log("");
        console.log("=== All checks passed - Router is correctly configured ===");
    }
}
