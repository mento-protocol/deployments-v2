// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

// Import proxy contract
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeploySortedOracles is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        Senders.Sender storage deployer = sender("deployer");

        // Phase 1: Deploy SortedOracles implementation
        address sortedOraclesImpl = deployer
            .create3("SortedOracles")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false));

        // Phase 2: Deploy proxy without initialization
        address proxyAdmin = lookup("ProxyAdmin");
        require(proxyAdmin != address(0), "ProxyAdmin not deployed");

        address sortedOraclesProxy = deployer
            .create3("TransparentUpgradeableProxy")
            .setLabel("SortedOracles")
            .deploy(abi.encode(sortedOraclesImpl, proxyAdmin, ""));

        // Phase 3: Initialize SortedOracles through harness with config value
        ISortedOracles sortedOracles = ISortedOracles(
            deployer.harness(sortedOraclesProxy)
        );
        IMentoConfig.OracleConfig memory oracleConfig = config.getOracleConfig();
        sortedOracles.initialize(oracleConfig.reportExpirySeconds);
        
        console.log("SortedOracles initialized with report expiry:", oracleConfig.reportExpirySeconds, "seconds");
    }
}
