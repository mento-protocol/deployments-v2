// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

contract ConfigureOracleRateFeeds is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        Senders.Sender storage deployer = sender("deployer");

        // Get SortedOracles
        address sortedOraclesProxy = lookup("TransparentUpgradeableProxy:SortedOracles");
        require(sortedOraclesProxy != address(0), "SortedOracles not deployed");

        ISortedOracles sortedOracles = ISortedOracles(deployer.harness(sortedOraclesProxy));

        // Get configurations from config contract
        IMentoConfig.RateFeedConfig[] memory rateFeedConfigs = config.getRateFeedConfigs();
        address[] memory oracleAddresses = config.getOracleAddresses();

        require(oracleAddresses.length > 0, "No oracle addresses configured");

        // Configure rate feeds
        for (uint256 i = 0; i < rateFeedConfigs.length; i++) {
            // Calculate rate feed ID from asset pair
            address rateFeedId = config.getRateFeedId(rateFeedConfigs[i].asset0, rateFeedConfigs[i].asset1);
            
            // Add oracles for this rate feed
            for (uint256 j = 0; j < oracleAddresses.length; j++) {
                sortedOracles.addOracle(rateFeedId, oracleAddresses[j]);
            }
            
            console.log(
                string(abi.encodePacked("Added rate feed for ", rateFeedConfigs[i].id)),
                rateFeedId
            );
        }

        console.log("Configured rate feeds:", rateFeedConfigs.length);
        console.log("With oracle count:", oracleAddresses.length);
    }
}