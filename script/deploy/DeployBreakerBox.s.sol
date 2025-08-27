// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";
import {Config} from "../config/Config.sol";

contract DeployBreakerBox is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address breakerBoxAddy;
    address medianDeltaBreaker;
    address valueDeltaBreaker;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();

        Senders.Sender storage deployer = sender("deployer");

        deployBreakerBox(deployer);
        deployBreakers(deployer);

        // Initialize BreakerBox with deployed breakers
        IBreakerBox breakerBox = IBreakerBox(deployer.harness(breakerBoxAddy));
        breakerBox.addBreaker(medianDeltaBreaker, 1);
        breakerBox.addBreaker(valueDeltaBreaker, 1);

        ISortedOracles(deployer.harness(lookupProxyOrFail("SortedOracles")))
            .setBreakerBox(IBreakerBox(breakerBoxAddy));
    }

    function deployBreakers(Senders.Sender storage deployer) internal {
        address sortedOraclesProxy = lookupProxyOrFail("SortedOracles");

        address owner = deployer.account;
        uint256 defaultCooldownTime;
        uint256 defaultRateChangeThreshold;
        address[] memory rateFeedIds = new address[](0);
        uint256[] memory defaultRateChangeThresholds = new uint256[](0);
        uint256[] memory cooldownTimes = new uint256[](0);

        // Deploy MedianDeltaBreaker
        medianDeltaBreaker = deployer
            .create3("MedianDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    defaultCooldownTime,
                    defaultRateChangeThreshold,
                    sortedOraclesProxy,
                    breakerBoxAddy,
                    rateFeedIds,
                    defaultRateChangeThresholds,
                    cooldownTimes,
                    owner
                )
            );

        // Deploy ValueDeltaBreaker
        valueDeltaBreaker = deployer
            .create3("ValueDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    defaultCooldownTime,
                    defaultRateChangeThreshold,
                    sortedOraclesProxy,
                    rateFeedIds,
                    defaultRateChangeThresholds,
                    cooldownTimes,
                    owner
                )
            );
    }

    function deployBreakerBox(Senders.Sender storage deployer) internal {
        // Deploy BreakerBox with empty rate feed IDs and SortedOracles dependency
        address sortedOraclesProxy = lookupProxyOrFail("SortedOracles");
        address[] memory rateFeedIds = config.getRateFeedIds();
        require(rateFeedIds.length > 0);

        breakerBoxAddy = deployer
            .create3("BreakerBox")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(rateFeedIds, sortedOraclesProxy, deployer.account)
            );
    }
}
