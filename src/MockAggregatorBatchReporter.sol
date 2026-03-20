// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.33;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IMockChainlinkAggregator {
    function report(int256 _answer, uint256 _lastUpdated) external;
}

contract MockAggregatorBatchReporter is Ownable {
    event MockAggregatorReport(address indexed aggregator, int256 answer, uint256 timestamp);

    address public reporter;

    modifier onlyReporter() {
        require(msg.sender == reporter, "MockAggregatorBatchReporter: caller is not the reporter");
        _;
    }

    constructor(address _owner, address _reporter) Ownable(_owner) {
        reporter = _reporter;
    }

    function setReporter(address _reporter) external onlyOwner {
        reporter = _reporter;
    }

    function batchReport(
        address[] calldata aggregators,
        int256[] calldata answers,
        uint256[] calldata timestamps
    ) external onlyReporter {
        require(
            aggregators.length == answers.length && aggregators.length == timestamps.length,
            "MockAggregatorBatchReporter: array length mismatch"
        );

        for (uint256 i = 0; i < aggregators.length; i++) {
            IMockChainlinkAggregator(aggregators[i]).report(answers[i], timestamps[i]);
            emit MockAggregatorReport(aggregators[i], answers[i], timestamps[i]);
        }
    }
}
