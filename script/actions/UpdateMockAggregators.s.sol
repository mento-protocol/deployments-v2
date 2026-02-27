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

contract UpdateMockAggregators is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:env {uint256} offset - Optional: skip the first N aggregators (0-based, default 0)
    /// @custom:env {uint256} limit - Optional: max number of aggregators to update (default all)
    /// @custom:senders reporter,deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage reporter = sender("reporter");

        IMentoConfig.MockAggregatorConfig[] memory aggConfigs = config
            .getMockAggregatorConfigs();

        uint256 start = 0;
        try vm.envUint("offset") returns (uint256 o) {
            start = o;
        } catch {}
        require(start < aggConfigs.length, "offset out of bounds");

        uint256 end = aggConfigs.length;
        try vm.envUint("limit") returns (uint256 l) {
            end = start + l;
            if (end > aggConfigs.length) end = aggConfigs.length;
        } catch {}

        vm.selectFork(config.mockAggregatorSourceFork());

        int256[] memory answers = new int256[](end - start);
        uint256[] memory timestamps = new uint256[](end - start);

        for (uint i = start; i < end; i++) {
            AggregatorV3Interface agg = AggregatorV3Interface(
                aggConfigs[i].source
            );

            (, answers[i - start], , timestamps[i - start], ) = agg
                .latestRoundData();
        }

        vm.selectFork(config.baseFork());

        for (uint i = start; i < end; i++) {
            address aggAddy = lookupOrFail(
                string.concat(
                    "MockChainlinkAggregator:",
                    aggConfigs[i].description
                )
            );
            MockChainlinkAggregator(reporter.harness(aggAddy)).report(
                answers[i - start],
                timestamps[i - start]
            );
        }
    }
}
