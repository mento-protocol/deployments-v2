// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {MockChainlinkAggregator} from "src/MockChainlinkAggregator.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";

contract DeployMockAggregators is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        IMentoConfig config = Config.get();
        Senders.Sender storage deployer = sender("deployer");

        IMentoConfig.MockAggregatorConfig[] memory aggConfigs = config
            .getMockAggregatorConfigs();

        for (uint i = 0; i < aggConfigs.length; i++) {
            address aggAddy = deployer
                .create3("MockChainlinkAggregator")
                .setLabel(aggConfigs[i].description)
                .deploy(
                    abi.encode(
                        aggConfigs[i].description,
                        aggConfigs[i].decimals,
                        deployer.account
                    )
                );
            MockChainlinkAggregator agg = MockChainlinkAggregator(
                deployer.harness(aggAddy)
            );
            agg.setExternalProvider(config.mockAggregatorReporter());
            agg.report(aggConfigs[i].initialReport, block.timestamp);
        }
    }
}
