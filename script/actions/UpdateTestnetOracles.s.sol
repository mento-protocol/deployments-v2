// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

import {AggregatorV3Interface} from "lib/mento-core/lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";
import {MockChainlinkAggregator} from "src/MockChainlinkAggregator.sol";

contract UpdateTestnetOracles is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders reporter,deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage reporter = sender("reporter");

        IMentoConfig.MockAggregatorConfig[] memory aggConfigs = config
            .getMockAggregatorConfigs();

        vm.selectFork(config.mockAggregatorSourceFork());

        int256[] memory answers = new int256[](aggConfigs.length);
        uint256[] memory timestamps = new uint256[](aggConfigs.length);

        for (uint i = 0; i < aggConfigs.length; i++) {
            AggregatorV3Interface agg = AggregatorV3Interface(
                aggConfigs[i].source
            );

            (, answers[i], , timestamps[i], ) = agg.latestRoundData();
        }

        vm.selectFork(config.baseFork());

        for (uint i = 0; i < aggConfigs.length; i++) {
            address aggAddy = lookupOrFail(
                string.concat(
                    "MockChainlinkAggregator:",
                    aggConfigs[i].description
                )
            );
            MockChainlinkAggregator(reporter.harness(aggAddy)).report(
                answers[i],
                timestamps[i]
            );
        }

        IMentoConfig.ChainlinkRelayerConfig[] memory relayerConfigs = config
            .getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < relayerConfigs.length; i++) {
            address relayerAddy = lookupOrFail(
                string.concat("ChainlinkRelayerV1:", relayerConfigs[i].rateFeed)
            );

            try
                IChainlinkRelayer(reporter.harness(relayerAddy)).relay()
            {} catch {
                console.log("Error reporting: ", relayerAddy);
            }
        }
    }
}
