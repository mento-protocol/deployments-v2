// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ITrebEvents} from "lib/treb-sol/src/internal/ITrebEvents.sol";
import {Harness} from "lib/treb-sol/src/internal/Harness.sol";

import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {IMedianDeltaBreaker} from "lib/mento-core/contracts/interfaces/IMedianDeltaBreaker.sol";
import {IValueDeltaBreaker} from "lib/mento-core/contracts/interfaces/IValueDeltaBreaker.sol";

import {Config, IMentoConfig, BreakerType} from "script/config/Config.sol";
import {ProxyHelper, ProxyType} from "script/helpers/ProxyHelper.sol";

interface ISortedOraclesSetter is ISortedOracles {
    function setTokenReportExpiry(address rateFeedId, uint256 expiry) external;
}

/// @dev The upstream IValueDeltaBreaker/IMedianDeltaBreaker interfaces declare
///      `getCoolDown` (capital D), but the actual WithCooldown contract exposes
///      `getCooldown` (lowercase d). This wrapper provides the correct selector.
interface IWithCooldown {
    function getCooldown(address rateFeedID) external view returns (uint256);
}

/**
 * @title AddRateFeed
 * @notice Configures new rate feeds in the Mento protocol by:
 *         1. Deploying Chainlink relayers via the factory
 *         2. Adding relayers as oracles in SortedOracles
 *         3. Adding rate feed IDs to the BreakerBox and enabling breakers
 *
 *         The script is idempotent — it skips any step that has already been performed.
 */
contract AddRateFeed is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer,migrationOwner
    function run() public broadcast {
        IMentoConfig config = Config.get();

        Senders.Sender storage migrationOwner = sender("migrationOwner");

        // Look up deployed infrastructure
        address chainlinkRelayerFactoryProxy = lookupProxyOrFail("ChainlinkRelayerFactory", ProxyType.OZTUP);
        address sortedOraclesProxy = lookupProxyOrFail("SortedOracles");
        address breakerBoxAddy = lookupOrFail("BreakerBox:v2.6.5");

        // Harnessed interfaces for state-changing calls (via migrationOwner)
        IChainlinkRelayerFactory factory =
            IChainlinkRelayerFactory(migrationOwner.harness(chainlinkRelayerFactoryProxy));
        ISortedOraclesSetter sortedOracles = ISortedOraclesSetter(migrationOwner.harness(sortedOraclesProxy));
        IBreakerBox breakerBox = IBreakerBox(migrationOwner.harness(breakerBoxAddy));

        // Read-only interfaces (no harness needed)
        IChainlinkRelayerFactory factoryRead = IChainlinkRelayerFactory(chainlinkRelayerFactoryProxy);
        ISortedOracles sortedOraclesRead = ISortedOracles(sortedOraclesProxy);
        IBreakerBox breakerBoxRead = IBreakerBox(breakerBoxAddy);

        // ── Step 1 & 2: Deploy relayers and add as oracles ──────────────────
        _deployRelayersAndAddOracles(config, factory, factoryRead, sortedOracles, sortedOraclesRead, migrationOwner);

        // ── Step 3: Add rate feeds to BreakerBox and enable breakers ────────
        _configureBreakerBox(config, breakerBox, breakerBoxRead, migrationOwner);
    }

    function _deployRelayersAndAddOracles(
        IMentoConfig config,
        IChainlinkRelayerFactory factory,
        IChainlinkRelayerFactory factoryRead,
        ISortedOraclesSetter sortedOracles,
        ISortedOracles sortedOraclesRead,
        Senders.Sender storage migrationOwner
    ) internal {
        IMentoConfig.ChainlinkRelayerConfig[] memory relayerConfigs = config.getChainlinkRelayerConfigs();

        if (relayerConfigs.length == 0) {
            console.log("No Chainlink relayers configured");
            return;
        }

        for (uint256 i = 0; i < relayerConfigs.length; i++) {
            address rateFeedId = relayerConfigs[i].rateFeedId;
            address existingRelayer = factoryRead.getRelayer(rateFeedId);

            if (existingRelayer != address(0)) {
                // Relayer already deployed — still ensure it's registered as oracle
                if (!sortedOraclesRead.isOracle(rateFeedId, existingRelayer)) {
                    sortedOracles.addOracle(rateFeedId, existingRelayer);
                    console.log(
                        string.concat("Added existing relayer as oracle for ", relayerConfigs[i].rateFeed),
                        existingRelayer
                    );
                }
            } else {
                // Deploy new relayer through factory
                address relayer = factory.deployRelayer(
                    rateFeedId,
                    relayerConfigs[i].rateFeedDescription,
                    relayerConfigs[i].maxTimestampSpread,
                    relayerConfigs[i].aggregators
                );

                _emitRelayerDeployedEvent(factory, relayer, relayerConfigs[i]);
                console.log(string.concat("Deployed Chainlink relayer for ", relayerConfigs[i].rateFeed), relayer);

                // Add relayer as oracle for this rate feed
                sortedOracles.addOracle(rateFeedId, relayer);
            }

            // Set report expiry if configured and not already set
            uint256 expiry = config.getRateFeedExpirySeconds(relayerConfigs[i].rateFeed);
            if (expiry > 0) {
                uint256 currentExpiry = sortedOraclesRead.getTokenReportExpirySeconds(rateFeedId);
                console.log("Current expiry for", relayerConfigs[i].rateFeed, currentExpiry);
                if (currentExpiry != expiry) {
                    sortedOracles.setTokenReportExpiry(rateFeedId, expiry);
                    console.log(string.concat("Set report expiry for ", relayerConfigs[i].rateFeed), expiry);
                }
            }
        }
    }

    function _emitRelayerDeployedEvent(
        IChainlinkRelayerFactory factory,
        address relayer,
        IMentoConfig.ChainlinkRelayerConfig memory relayerConfig
    ) internal {
        bytes memory constructorArgs = abi.encode(
            relayerConfig.rateFeedId,
            relayerConfig.rateFeedDescription,
            relayerConfig.maxTimestampSpread,
            relayerConfig.aggregators
        );

        bytes memory chainlinkRelayerV1Code = vm.getCode("ChainlinkRelayerV1");

        emit ITrebEvents.ContractDeployed(
            address(factory),
            relayer,
            Harness(payable(address(factory))).lastTransactionId(),
            ITrebEvents.DeploymentDetails({
                artifact: "ChainlinkRelayerV1",
                label: relayerConfig.rateFeed,
                entropy: "",
                salt: keccak256("mento.chainlinkRelayer"),
                bytecodeHash: keccak256(chainlinkRelayerV1Code),
                initCodeHash: keccak256(abi.encode(chainlinkRelayerV1Code, constructorArgs)),
                constructorArgs: constructorArgs,
                createStrategy: "CREATE2"
            })
        );
    }

    function _configureBreakerBox(
        IMentoConfig config,
        IBreakerBox breakerBox,
        IBreakerBox breakerBoxRead,
        Senders.Sender storage migrationOwner
    ) internal {
        // First, ensure all rate feeds are added to the BreakerBox
        address[] memory rateFeedIds = config.getRateFeedIds();
        for (uint256 i = 0; i < rateFeedIds.length; i++) {
            if (!breakerBoxRead.rateFeedStatus(rateFeedIds[i])) {
                breakerBox.addRateFeed(rateFeedIds[i]);
                console.log(string.concat("BreakerBox: added rate feed ", vm.getLabel(rateFeedIds[i])), rateFeedIds[i]);
            }
        }

        // Get existing breakers from the BreakerBox
        address[] memory existingBreakers = breakerBoxRead.getBreakers();

        // Enable breakers for rate feeds based on config
        IMentoConfig.BreakerConfig[] memory breakerConfigs = config.getBreakerConfigs();
        for (uint256 i = 0; i < breakerConfigs.length; i++) {
            // Find the matching deployed breaker by type
            address breakerAddress = _findBreakerByType(breakerConfigs[i].breakerType, existingBreakers);
            require(breakerAddress != address(0), "No deployed breaker found for breaker config index");

            // Create harnessed write address once per breaker
            address breakerWrite = migrationOwner.harness(breakerAddress);

            for (uint256 j = 0; j < breakerConfigs[i].rateFeedIds.length; j++) {
                address rateFeedId = breakerConfigs[i].rateFeedIds[j];

                // Skip if rate feed is not in the BreakerBox
                require(breakerBoxRead.rateFeedStatus(rateFeedId), "Rate feed not in BreakerBox");

                // Enable breaker for this rate feed if not already enabled
                if (!breakerBoxRead.isBreakerEnabled(breakerAddress, rateFeedId)) {
                    string memory breakerType =
                        breakerConfigs[i].breakerType == BreakerType.Value ? "ValueBreaker" : "MedianBreaker";
                    console.log(string.concat("BreakerBox: enabling ", breakerType, " for ", vm.getLabel(rateFeedId)));
                    breakerBox.toggleBreaker(breakerAddress, rateFeedId, true);
                }

                // Configure breaker-specific parameters for new rate feeds
                _configureBreakerParams(breakerConfigs[i], breakerAddress, breakerWrite, j);
            }
        }

        // Set rate feed dependencies
        for (uint256 i = 0; i < rateFeedIds.length; i++) {
            address[] memory deps = config.getRateFeedDependencies(rateFeedIds[i]);
            if (deps.length > 0) {
                breakerBox.setRateFeedDependencies(rateFeedIds[i], deps);
            }
        }

        // Enable MarketHoursBreaker on FX Feeds.
        // TODO: Move this to the breakers config per network?
        address[] memory fxFeedIds = config.getFxRateFeedIds();
        address marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            if (!breakerBoxRead.isBreakerEnabled(marketHoursBreaker, fxFeedIds[i])) {
                console.log(string.concat("BreakerBox: enabling MarketHoursBreaker for ", vm.getLabel(fxFeedIds[i])));
                breakerBox.toggleBreaker(marketHoursBreaker, fxFeedIds[i], true);
            }
        }
    }

    function _findBreakerByType(BreakerType breakerType, address[] memory existingBreakers)
        internal
        view
        returns (address)
    {
        for (uint256 i = 0; i < existingBreakers.length; i++) {
            if (breakerType == BreakerType.Median) {
                // Check if this is a MedianDeltaBreaker by looking for the DEFAULT_SMOOTHING_FACTOR selector
                try IMedianDeltaBreaker(existingBreakers[i]).DEFAULT_SMOOTHING_FACTOR() returns (uint256) {
                    return existingBreakers[i];
                } catch {
                    continue;
                }
            } else if (breakerType == BreakerType.Value) {
                // Check if this is a ValueDeltaBreaker by looking for the referenceValues selector
                try IValueDeltaBreaker(existingBreakers[i]).referenceValues(address(0)) returns (uint256) {
                    return existingBreakers[i];
                } catch {
                    continue;
                }
            }
        }
        return address(0);
    }

    function _configureBreakerParams(
        IMentoConfig.BreakerConfig memory breakerConfig,
        address breakerRead,
        address breakerWrite,
        uint256 rateFeedIndex
    ) internal {
        address rateFeedId = breakerConfig.rateFeedIds[rateFeedIndex];
        string memory rateFeedName = vm.getLabel(rateFeedId);

        address[] memory rateFeedIds = new address[](1);
        rateFeedIds[0] = rateFeedId;

        if (breakerConfig.breakerType == BreakerType.Value) {
            // Configure ValueDeltaBreaker for rate feed
            uint256[] memory thresholds = new uint256[](1);
            thresholds[0] = breakerConfig.thresholds[rateFeedIndex];
            if (IValueDeltaBreaker(breakerRead).rateChangeThreshold(rateFeedId) != thresholds[0]) {
                console.log(string.concat("ValueBreaker: setting threshold for ", rateFeedName), thresholds[0]);
                IValueDeltaBreaker(breakerWrite).setRateChangeThresholds(rateFeedIds, thresholds);
            }

            uint256[] memory cooldowns = new uint256[](1);
            cooldowns[0] = breakerConfig.cooldownTimes[rateFeedIndex];
            if (IWithCooldown(breakerRead).getCooldown(rateFeedId) != cooldowns[0]) {
                console.log(string.concat("ValueBreaker: setting cooldown for ", rateFeedName), cooldowns[0]);
                IValueDeltaBreaker(breakerWrite).setCooldownTimes(rateFeedIds, cooldowns);
            }

            uint256[] memory refValues = new uint256[](1);
            refValues[0] = breakerConfig.referenceValues[rateFeedIndex];
            if (IValueDeltaBreaker(breakerRead).referenceValues(rateFeedId) != refValues[0]) {
                console.log(string.concat("ValueBreaker: setting reference value for ", rateFeedName), refValues[0]);
                IValueDeltaBreaker(breakerWrite).setReferenceValues(rateFeedIds, refValues);
            }
        } else if (breakerConfig.breakerType == BreakerType.Median) {
            // Configure MedianDeltaBreaker for rate feed
            uint256[] memory thresholds = new uint256[](1);
            thresholds[0] = breakerConfig.thresholds[rateFeedIndex];
            if (IMedianDeltaBreaker(breakerRead).rateChangeThreshold(rateFeedId) != thresholds[0]) {
                console.log(string.concat("MedianBreaker: setting threshold for ", rateFeedName), thresholds[0]);
                IMedianDeltaBreaker(breakerWrite).setRateChangeThresholds(rateFeedIds, thresholds);
            }

            uint256[] memory cooldowns = new uint256[](1);
            cooldowns[0] = breakerConfig.cooldownTimes[rateFeedIndex];
            if (IWithCooldown(breakerRead).getCooldown(rateFeedId) != cooldowns[0]) {
                console.log(string.concat("MedianBreaker: setting cooldown for ", rateFeedName), cooldowns[0]);
                IMedianDeltaBreaker(breakerWrite).setCooldownTime(rateFeedIds, cooldowns);
            }

            if (breakerConfig.smoothingFactors[rateFeedIndex] > 0) {
                if (
                    IMedianDeltaBreaker(breakerRead).getSmoothingFactor(rateFeedId)
                        != breakerConfig.smoothingFactors[rateFeedIndex]
                ) {
                    console.log(
                        string.concat("MedianBreaker: setting smoothing factor for ", rateFeedName),
                        breakerConfig.smoothingFactors[rateFeedIndex]
                    );
                    IMedianDeltaBreaker(breakerWrite)
                        .setSmoothingFactor(rateFeedId, breakerConfig.smoothingFactors[rateFeedIndex]);
                }
            }
        }
    }
}
