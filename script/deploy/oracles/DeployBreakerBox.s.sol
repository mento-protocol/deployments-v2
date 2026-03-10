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

import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {ConfigHelper} from "script/helpers/ConfigHelper.sol";
import {Config, IMentoConfig, BreakerType} from "script/config/Config.sol";

contract DeployBreakerBox is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address breakerBoxAddy;
    address sortedOraclesProxy;

    Senders.Sender deployer;
    Senders.Sender migrationOwner;

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        // Get configuration
        sortedOraclesProxy = lookupProxyOrFail("SortedOracles");

        deployer = sender("deployer");
        migrationOwner = sender("migrationOwner");

        deployBreakerBox();
        (address[] memory breakers, address[][] memory rateFeedIds) = deployBreakers();

        // Initialize BreakerBox with deployed breakers
        IBreakerBox breakerBox = IBreakerBox(migrationOwner.harness(breakerBoxAddy));
        IBreakerBox breakerBoxRead = IBreakerBox(breakerBoxAddy);
        for (uint256 i = 0; i < breakers.length; i++) {
            if (!breakerBoxRead.isBreaker(breakers[i])) {
                breakerBox.addBreaker(breakers[i], 1);
            }
            for (uint256 j = 0; j < rateFeedIds[i].length; j++) {
                if (!breakerBoxRead.isBreakerEnabled(breakers[i], rateFeedIds[i][j])) {
                    breakerBox.toggleBreaker(breakers[i], rateFeedIds[i][j], true);
                }
            }
        }

        ISortedOracles(migrationOwner.harness(sortedOraclesProxy)).setBreakerBox(IBreakerBox(breakerBoxAddy));

        address[] memory rateFeeds = config.getRateFeedIds();
        for (uint256 i = 0; i < rateFeeds.length; i++) {
            address[] memory deps = config.getRateFeedDependencies(rateFeeds[i]);
            if (deps.length > 0) {
                breakerBox.setRateFeedDependencies(rateFeeds[i], deps);
            }
        }
    }

    function deployBreakers()
        internal
        returns (address[] memory breakers, address[][] memory rateFeeds)
    {
        IMentoConfig.BreakerConfig[] memory breakerConfigs = config.getBreakerConfigs();
        breakers = new address[](breakerConfigs.length);
        rateFeeds = new address[][](breakerConfigs.length);
        console.log(breakerConfigs.length);
        for (uint256 i = 0; i < breakerConfigs.length; i++) {
            if (breakerConfigs[i].breakerType == BreakerType.Value) {
                breakers[i] = deployValueDeltaBreaker(breakerConfigs[i]);
            } else if (breakerConfigs[i].breakerType == BreakerType.Median) {
                breakers[i] = deployMedianDeltaBreaker(breakerConfigs[i]);
            } else {
                revert("Invalid breaker type");
            }
            rateFeeds[i] = breakerConfigs[i].rateFeedIds;
        }
    }

    function deployMedianDeltaBreaker(IMentoConfig.BreakerConfig memory breakerConfig)
        internal
        returns (address breakerAddy)
    {
        breakerAddy = deployer.create3("MedianDeltaBreaker").setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    breakerConfig.defaultCooldownTime,
                    breakerConfig.defaultThreshold,
                    sortedOraclesProxy,
                    breakerBoxAddy,
                    breakerConfig.rateFeedIds,
                    breakerConfig.thresholds,
                    breakerConfig.cooldownTimes,
                    migrationOwner.account
                )
            );

        IMedianDeltaBreaker breaker = IMedianDeltaBreaker(migrationOwner.harness(breakerAddy));
        for (uint256 i = 0; i < breakerConfig.rateFeedIds.length; i++) {
            if (breakerConfig.smoothingFactors[i] > 0) {
                breaker.setSmoothingFactor(breakerConfig.rateFeedIds[i], breakerConfig.smoothingFactors[i]);
            }
        }
    }

    function deployValueDeltaBreaker(IMentoConfig.BreakerConfig memory breakerConfig)
        internal
        returns (address breakerAddy)
    {
        breakerAddy = deployer.create3("ValueDeltaBreaker").setLabel("v2.6.5")
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

        IValueDeltaBreaker(deployer.harness(breakerAddy))
            .setReferenceValues(breakerConfig.rateFeedIds, breakerConfig.referenceValues);
    }

    function deployBreakerBox() internal {
        // Deploy BreakerBox with empty rate feed IDs and SortedOracles dependency
        address[] memory rateFeedIds = config.getRateFeedIds();
        require(rateFeedIds.length > 0);

        breakerBoxAddy = deployer.create3("BreakerBox").setLabel("v2.6.5")
            .deploy(abi.encode(rateFeedIds, sortedOraclesProxy, migrationOwner.account));
    }
}
