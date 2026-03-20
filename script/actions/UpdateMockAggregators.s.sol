// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

import {
    AggregatorV3Interface
} from "lib/mento-core/lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";
import {MockAggregatorBatchReporter} from "src/MockAggregatorBatchReporter.sol";

contract UpdateMockAggregators is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:env {uint256:optional} offset - Skip the first N aggregators (0-based, default 0)
    /// @custom:env {uint256:optional} limit - Max number of aggregators to update (default all)
    /// @custom:senders deployer, reporter
    function run() public broadcast {
        config = Config.get();
        Senders.Sender storage reporter = sender("reporter");

        IMentoConfig.MockAggregatorConfig[] memory aggConfigs = config.getMockAggregatorConfigs();

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

        uint256 count = end - start;

        // Fetch answers and timestamps from the source fork (mainnet)
        vm.selectFork(config.mockAggregatorSourceFork());

        address[] memory aggregators = new address[](count);
        int256[] memory answers = new int256[](count);
        uint256[] memory timestamps = new uint256[](count);

        for (uint256 i = start; i < end; i++) {
            AggregatorV3Interface agg = AggregatorV3Interface(aggConfigs[i].source);
            (, answers[i - start],, timestamps[i - start],) = agg.latestRoundData();
        }

        // Switch to target fork and batch-report all updates in a single tx
        vm.selectFork(config.baseFork());

        address reporterContract = lookupOrFail("MockAggregatorBatchReporter");
        console.log("\n");
        for (uint256 i = start; i < end; i++) {
            aggregators[i - start] = lookupOrFail(string.concat("MockChainlinkAggregator:", aggConfigs[i].label));
            console.log("Updating %s (%s)", aggConfigs[i].description, aggregators[i - start]);
            console.log(" > answer:", answers[i - start]);
            console.log(" > timestamp:", timestamps[i - start]);
            console.log("\n");
        }

        MockAggregatorBatchReporter(reporter.harness(reporterContract)).batchReport(aggregators, answers, timestamps);
    }
}
