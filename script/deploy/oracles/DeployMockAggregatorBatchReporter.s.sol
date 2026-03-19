// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

import {MockAggregatorBatchReporter} from "src/MockAggregatorBatchReporter.sol";
import {Config, IMentoConfig} from "script/config/Config.sol";

contract DeployMockAggregatorBatchReporter is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        IMentoConfig config = Config.get();
        Senders.Sender storage deployer = sender("deployer");

        address reporterEOA = config.mockAggregatorReporter();

        address reporterAddy =
            deployer.create3("MockAggregatorBatchReporter").deploy(abi.encode(deployer.account, reporterEOA));

        console.log("MockAggregatorBatchReporter deployed at:", reporterAddy);
        console.log("Owner: ", IOwnable(reporterAddy).owner());
        console.log("Reporter: ", MockAggregatorBatchReporter(reporterAddy).reporter());
    }
}
