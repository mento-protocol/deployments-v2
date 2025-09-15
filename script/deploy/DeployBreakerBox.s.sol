// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IMedianDeltaBreaker} from "lib/mento-core/contracts/interfaces/IMedianDeltaBreaker.sol";
import {IValueDeltaBreaker} from "lib/mento-core/contracts/interfaces/IValueDeltaBreaker.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";
import {Config, IMentoConfig, BreakerType} from "../config/Config.sol";

contract DeployBreakerBox is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address breakerBoxAddy;
    address sortedOraclesProxy;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        sortedOraclesProxy = lookupProxyOrFail("SortedOracles");

        Senders.Sender storage deployer = sender("deployer");

        deployBreakerBox(deployer);
        (
            address[] memory breakers,
            address[][] memory rateFeedIds
        ) = deployBreakers(deployer);

        // Initialize BreakerBox with deployed breakers
        IBreakerBox breakerBox = IBreakerBox(deployer.harness(breakerBoxAddy));
        IBreakerBox breakerBoxRead = IBreakerBox(breakerBoxAddy);
        for (uint i = 0; i < breakers.length; i++) {
            if (!breakerBoxRead.isBreaker(breakers[i])) {
                breakerBox.addBreaker(breakers[i], 1);
            }
            for (uint j = 0; j < rateFeedIds[i].length; j++) {
                if (!breakerBoxRead.isBreakerEnabled(breakers[i], rateFeedIds[i][j])) {
                    breakerBox.toggleBreaker(breakers[i], rateFeedIds[i][j], true);
                }
            }
        }

        ISortedOracles(deployer.harness(sortedOraclesProxy)).setBreakerBox(
            IBreakerBox(breakerBoxAddy)
        );

        address[] memory rateFeeds = config.getRateFeedIds();
        for (uint i = 0; i < rateFeeds.length; i++) {
            address[] memory deps = config.getRateFeedDependencies(rateFeeds[i]);
            if (deps.length > 0) {
                breakerBox.setRateFeedDependencies(rateFeeds[i], deps);
            }
        }
    }

    function deployBreakers(
        Senders.Sender storage deployer
    ) internal returns (address[] memory breakers, address[][] memory rateFeeds) {
        IMentoConfig.BreakerConfig[] memory breakerConfigs = config
            .getBreakerConfigs();
        breakers = new address[](breakerConfigs.length);
        rateFeeds = new address[][](breakerConfigs.length);
        console.log(breakerConfigs.length);
        for (uint i = 0; i < breakerConfigs.length; i++) {
            if (breakerConfigs[i].breakerType == BreakerType.Value) {
                breakers[i] = deployValueDeltaBreaker(
                    deployer,
                    breakerConfigs[i]
                );
            } else if (breakerConfigs[i].breakerType == BreakerType.Median) {
                breakers[i] = deployMedianDeltaBreaker(
                    deployer,
                    breakerConfigs[i]
                );
            } else {
                revert("Invalid breaker type");
            }
            rateFeeds[i] = breakerConfigs[i].rateFeedIds;
        }
    }

    function deployMedianDeltaBreaker(
        Senders.Sender storage deployer,
        IMentoConfig.BreakerConfig memory breakerConfig
    ) internal returns (address breakerAddy) {
        breakerAddy = deployer
            .create3("MedianDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    breakerConfig.defaultCooldownTime,
                    breakerConfig.defaultThreshold,
                    sortedOraclesProxy,
                    breakerBoxAddy,
                    breakerConfig.rateFeedIds,
                    breakerConfig.thresholds,
                    breakerConfig.cooldownTimes,
                    deployer.account
                )
            );

        IMedianDeltaBreaker breaker = IMedianDeltaBreaker(
            deployer.harness(breakerAddy)
        );
        for (uint i = 0; i < breakerConfig.rateFeedIds.length; i++) {
            if (breakerConfig.smoothingFactors[i] > 0) {
                breaker.setSmoothingFactor(
                    breakerConfig.rateFeedIds[i],
                    breakerConfig.smoothingFactors[i]
                );
            }
        }
    }

    function deployValueDeltaBreaker(
        Senders.Sender storage deployer,
        IMentoConfig.BreakerConfig memory breakerConfig
    ) internal returns (address breakerAddy) {
        breakerAddy = deployer
            .create3("ValueDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    breakerConfig.defaultCooldownTime,
                    breakerConfig.defaultThreshold,
                    sortedOraclesProxy,
                    breakerConfig.rateFeedIds,
                    breakerConfig.thresholds,
                    breakerConfig.cooldownTimes,
                    deployer.account
                )
            );

        IValueDeltaBreaker(deployer.harness(breakerAddy)).setReferenceValues(
            breakerConfig.rateFeedIds,
            breakerConfig.referenceValues
        );
    }

    function deployBreakerBox(Senders.Sender storage deployer) internal {
        // Deploy BreakerBox with empty rate feed IDs and SortedOracles dependency
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
