// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

import {MockAggregatorReporter} from "src/MockAggregatorReporter.sol";

contract DeployMockAggregatorReporter is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer, reporter
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage reporter = sender("reporter");

        IMentoConfig config = Config.get();
        address reporterEOA = reporter.account;

        address reporterAddy =
            deployer.create3("MockAggregatorReporter").deploy(abi.encode(deployer.account, reporterEOA));

        console.log("MockAggregatorReporter deployed at:", reporterAddy);
        console.log("Owner: ", IOwnable(reporterAddy).owner());
        console.log("Reporter: ", MockAggregatorReporter(reporterAddy).reporter());
    }
}
