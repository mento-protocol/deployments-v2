// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IStableTokenV3} from "lib/mento-core/contracts/interfaces/IStableTokenV3.sol";

import {ProxyHelper, ILegacyProxy, ProxyType} from "../helpers/ProxyHelper.sol";

contract UpgradeStableTokenV3 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;

    Senders.Sender owner;

    /// @custom:senders deployer, migrationOwner
    /// @custom:env {string} TOKEN_SYMBOL - Symbol of the token to upgrade (e.g. "cUSD")
    function run() public virtual broadcast {
        owner = sender("migrationOwner");

        string memory tokenSymbol = vm.envString("TOKEN_SYMBOL");

        // Look up addresses
        address v3Impl = lookupOrFail("StableTokenV3:v3.0.0");
        address tokenProxy = lookupOrFail(string.concat("Proxy:", tokenSymbol));
        address broker = lookupOrFail("Proxy:Broker");

        console.log("Upgrading %s to StableTokenV3", tokenSymbol);
        console.log("  proxy:", tokenProxy);
        console.log("  new impl:", v3Impl);
        console.log("  broker (minter+burner):", broker);

        // Build initializeV3 calldata: minters=[broker], burners=[broker], operators=[]
        address[] memory minters = new address[](1);
        minters[0] = broker;
        address[] memory burners = new address[](1);
        burners[0] = broker;
        address[] memory operators = new address[](0);

        bytes memory initData = abi.encodeCall(
            IStableTokenV3.initializeV3,
            (minters, burners, operators)
        );

        // Upgrade proxy to V3 implementation with initializeV3
        ILegacyProxy proxy = ILegacyProxy(owner.harness(tokenProxy));
        proxy._setAndInitializeImplementation(v3Impl, initData);

        // Post-checks
        verifyProxyImpl(tokenSymbol, tokenProxy, v3Impl);

        require(
            IStableTokenV3(tokenProxy).isMinter(broker),
            "Broker is not a minter after upgrade"
        );
        require(
            IStableTokenV3(tokenProxy).isBurner(broker),
            "Broker is not a burner after upgrade"
        );

        console.log("Upgrade successful. Broker is minter: true, burner: true");
    }
}
