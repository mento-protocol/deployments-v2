// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

import {MockChainlinkAggregator} from "src/MockChainlinkAggregator.sol";

contract UpdateMockAggregatorProvider is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        config = Config.get();
        Senders.Sender storage deployer = sender("deployer");

        IMentoConfig.MockAggregatorConfig[] memory aggConfigs = config.getMockAggregatorConfigs();
        address reporterContract = lookupOrFail("MockAggregatorReporter");

        for (uint256 i = 0; i < aggConfigs.length; i++) {
            address aggAddy = lookupOrFail(string.concat("MockChainlinkAggregator:", aggConfigs[i].label));
            MockChainlinkAggregator(deployer.harness(aggAddy)).setExternalProvider(reporterContract);
        }
    }
}
