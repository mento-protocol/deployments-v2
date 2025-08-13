// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

contract DeployStableTokenV2Implementation is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // Deploy StableTokenV2 implementation
        address stableTokenImpl = deployer
            .create3("StableTokenV2")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false)); // disable initializers

        console.log("StableTokenV2 implementation deployed at:", stableTokenImpl);
    }
}