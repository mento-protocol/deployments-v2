// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper, ILegacyProxy} from "../helpers/ProxyHelper.sol";

contract SwitchStableTokenV3WithParisEVM is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    string constant label = "v3.0.1";

    /// @custom:senders deployer, migrationOwner
    /// @custom:env {string} token - Symbol of the token to redeploy (e.g. "USDm")
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage owner = sender("migrationOwner");

        string memory tokenSymbol = vm.envString("token");
        address tokenProxy = lookupOrFail(string.concat("Proxy:", tokenSymbol));

        console.log("Token:", tokenSymbol);
        console.log("Proxy:", tokenProxy);

        // Try to find existing implementation, deploy if not found
        address v3Impl = lookup(string.concat("StableTokenV3:", label));
        if (v3Impl == address(0)) {
            console.log("StableTokenV3:%s not found, deploying...", label);
            v3Impl = deployer
                .create3("StableTokenV3")
                .setLabel(label)
                .deploy(abi.encode(true));
            console.log("Deployed StableTokenV3 impl:", v3Impl);
        } else {
            console.log("Found existing StableTokenV3 impl:", v3Impl);
        }

        // Switch proxy implementation (no re-initialization needed)
        address currentImpl = getProxyImplementation(tokenProxy);
        console.log("Current impl:", currentImpl);

        if (currentImpl == v3Impl) {
            console.log("Proxy already points to the correct implementation");
            return;
        }

        ILegacyProxy proxy = ILegacyProxy(owner.harness(tokenProxy));
        proxy._setImplementation(v3Impl);

        // Post-checks
        verifyProxyImpl(tokenSymbol, tokenProxy, v3Impl);
        console.log("Successfully switched %s to StableTokenV3:%s", tokenSymbol, label);
    }
}
