// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

contract DeployPricingModules is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // Deploy ConstantProductPricingModule
        deployer
            .create3("ConstantProductPricingModule")
            .setLabel("v2.6.5")
            .deploy();

        // Deploy ConstantSumPricingModule
        deployer.create3("ConstantSumPricingModule").setLabel("v2.6.5").deploy();
    }
}
