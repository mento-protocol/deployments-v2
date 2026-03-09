// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {IValueDeltaBreaker} from "lib/mento-core/contracts/interfaces/IValueDeltaBreaker.sol";
import {IMedianDeltaBreaker} from "lib/mento-core/contracts/interfaces/IMedianDeltaBreaker.sol";
import {IMentoConfig, BreakerType} from "script/config/IMentoConfig.sol";

/// @dev The deployed breaker contracts (Solidity ^0.5.13) use `getCooldown` (lowercase d),
///      but the ^0.8 interfaces declare `getCoolDown` (capital D). This local interface
///      matches the actual on-chain function selector.
interface IWithCooldown {
    function getCooldown(address rateFeedID) external view returns (uint256);
}

/**
 * @title BreakerVerification
 * @notice Verifies that the on-chain circuit breaker configuration matches config:
 *         - All config rate feeds are registered in BreakerBox
 *         - Breakers (Value/Median) are deployed and registered
 *         - Per-feed breaker enablement matches config
 *         - Per-feed cooldowns, thresholds, reference values, and smoothing factors match
 *         - Rate feed dependencies are set correctly
 */
contract BreakerVerification is V3IntegrationBase {
    address internal valueDeltaBreaker;
    address internal medianDeltaBreaker;
    IMentoConfig.BreakerConfig[] internal breakerConfigs;

    function setUp() public override {
        super.setUp();

        valueDeltaBreaker = registry.lookup("ValueDeltaBreaker:v2.6.5");
        medianDeltaBreaker = registry.lookup("MedianDeltaBreaker:v2.6.5");

        IMentoConfig.BreakerConfig[] memory configs = config.getBreakerConfigs();
        for (uint256 i = 0; i < configs.length; i++) {
            breakerConfigs.push(configs[i]);
        }
    }

    // ========== BreakerBox Registration ==========

    /// @notice Rate feeds that have a breaker configured must be registered in BreakerBox.
    ///         Rate feeds without breaker entries (e.g. informational feeds like CELOETH) are skipped.
    function test_allBreakerRateFeeds_registeredInBreakerBox() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                assertTrue(
                    IBreakerBox(breakerBox).rateFeedStatus(rateFeedId),
                    string.concat("Rate feed not registered in BreakerBox: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    /// @notice ValueDeltaBreaker must be deployed and registered as a breaker
    function test_valueDeltaBreaker_isRegistered() public view {
        assertNotEq(valueDeltaBreaker, address(0), "ValueDeltaBreaker not found in registry");
        assertTrue(
            IBreakerBox(breakerBox).isBreaker(valueDeltaBreaker), "ValueDeltaBreaker not registered in BreakerBox"
        );
    }

    /// @notice MedianDeltaBreaker must be deployed and registered as a breaker
    function test_medianDeltaBreaker_isRegistered() public view {
        assertNotEq(medianDeltaBreaker, address(0), "MedianDeltaBreaker not found in registry");
        assertTrue(
            IBreakerBox(breakerBox).isBreaker(medianDeltaBreaker), "MedianDeltaBreaker not registered in BreakerBox"
        );
    }

    // ========== Per-Feed Breaker Enablement ==========

    /// @notice Each rate feed in a Value breaker config must have that breaker enabled on-chain
    function test_valueBreakerConfig_enabledOnConfiguredFeeds() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Value) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                assertTrue(
                    IBreakerBox(breakerBox).isBreakerEnabled(valueDeltaBreaker, breakerConfigs[b].rateFeedIds[i]),
                    string.concat(
                        "ValueDeltaBreaker not enabled for rate feed: ", vm.toString(breakerConfigs[b].rateFeedIds[i])
                    )
                );
            }
        }
    }

    /// @notice Each rate feed in a Median breaker config must have that breaker enabled on-chain
    function test_medianBreakerConfig_enabledOnConfiguredFeeds() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Median) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                assertTrue(
                    IBreakerBox(breakerBox).isBreakerEnabled(medianDeltaBreaker, breakerConfigs[b].rateFeedIds[i]),
                    string.concat(
                        "MedianDeltaBreaker not enabled for rate feed: ", vm.toString(breakerConfigs[b].rateFeedIds[i])
                    )
                );
            }
        }
    }

    // ========== ValueDeltaBreaker Config Verification ==========

    /// @notice ValueDeltaBreaker per-feed cooldowns must match config
    function test_valueBreakerConfig_cooldownsMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Value) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].cooldownTimes[i];
                uint256 actual = IWithCooldown(valueDeltaBreaker).getCooldown(rateFeedId);
                assertEq(
                    actual,
                    expected,
                    string.concat("ValueDeltaBreaker cooldown mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    /// @notice ValueDeltaBreaker per-feed thresholds must match config
    function test_valueBreakerConfig_thresholdsMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Value) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].thresholds[i];
                uint256 actual = IValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(rateFeedId);
                assertEq(
                    actual,
                    expected,
                    string.concat("ValueDeltaBreaker threshold mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    /// @notice ValueDeltaBreaker per-feed reference values must match config
    function test_valueBreakerConfig_referenceValuesMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Value) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].referenceValues[i];
                uint256 actual = IValueDeltaBreaker(valueDeltaBreaker).referenceValues(rateFeedId);
                assertEq(
                    actual,
                    expected,
                    string.concat("ValueDeltaBreaker referenceValue mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    // ========== MedianDeltaBreaker Config Verification ==========

    /// @notice MedianDeltaBreaker per-feed cooldowns must match config
    function test_medianBreakerConfig_cooldownsMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Median) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].cooldownTimes[i];
                uint256 actual = IWithCooldown(medianDeltaBreaker).getCooldown(rateFeedId);
                assertEq(
                    actual,
                    expected,
                    string.concat("MedianDeltaBreaker cooldown mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    /// @notice MedianDeltaBreaker per-feed thresholds must match config
    function test_medianBreakerConfig_thresholdsMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Median) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].thresholds[i];
                uint256 actual = IMedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(rateFeedId);
                assertEq(
                    actual,
                    expected,
                    string.concat("MedianDeltaBreaker threshold mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    /// @notice MedianDeltaBreaker per-feed smoothing factors must match config
    function test_medianBreakerConfig_smoothingFactorsMatch() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Median) continue;

            for (uint256 i = 0; i < breakerConfigs[b].rateFeedIds.length; i++) {
                address rateFeedId = breakerConfigs[b].rateFeedIds[i];
                uint256 expected = breakerConfigs[b].smoothingFactors[i];
                uint256 actual = IMedianDeltaBreaker(medianDeltaBreaker).getSmoothingFactor(rateFeedId);
                // getSmoothingFactor returns DEFAULT_SMOOTHING_FACTOR (1e24) when not explicitly set (0 in config)
                if (expected == 0) {
                    expected = IMedianDeltaBreaker(medianDeltaBreaker).DEFAULT_SMOOTHING_FACTOR();
                }
                assertEq(
                    actual,
                    expected,
                    string.concat("MedianDeltaBreaker smoothingFactor mismatch for feed: ", vm.toString(rateFeedId))
                );
            }
        }
    }

    // ========== Rate Feed Dependencies ==========

    /// @notice Rate feed dependencies in config must match on-chain BreakerBox
    function test_rateFeedDependencies_matchConfig() public view {
        IMentoConfig.RateFeed[] memory rateFeeds = config.getRateFeeds();

        for (uint256 i = 0; i < rateFeeds.length; i++) {
            address rateFeedId = rateFeeds[i].rateFeedId;
            address[] memory expectedDeps = config.getRateFeedDependencies(rateFeedId);

            for (uint256 d = 0; d < expectedDeps.length; d++) {
                address actual = IBreakerBox(breakerBox).rateFeedDependencies(rateFeedId, d);
                assertEq(
                    actual,
                    expectedDeps[d],
                    string.concat("Dependency mismatch for '", rateFeeds[i].rateFeed, "' at index ", vm.toString(d))
                );
            }
        }
    }

    // ========== Default Breaker Parameters ==========

    /// @notice ValueDeltaBreaker default cooldown and threshold must match config
    function test_valueBreakerDefaults_matchConfig() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Value) continue;

            assertEq(
                IValueDeltaBreaker(valueDeltaBreaker).defaultCooldownTime(),
                breakerConfigs[b].defaultCooldownTime,
                "ValueDeltaBreaker default cooldown mismatch"
            );
            assertEq(
                IValueDeltaBreaker(valueDeltaBreaker).defaultRateChangeThreshold(),
                breakerConfigs[b].defaultThreshold,
                "ValueDeltaBreaker default threshold mismatch"
            );
        }
    }

    /// @notice MedianDeltaBreaker default cooldown and threshold must match config
    function test_medianBreakerDefaults_matchConfig() public view {
        for (uint256 b = 0; b < breakerConfigs.length; b++) {
            if (breakerConfigs[b].breakerType != BreakerType.Median) continue;

            assertEq(
                IMedianDeltaBreaker(medianDeltaBreaker).defaultCooldownTime(),
                breakerConfigs[b].defaultCooldownTime,
                "MedianDeltaBreaker default cooldown mismatch"
            );
            assertEq(
                IMedianDeltaBreaker(medianDeltaBreaker).defaultRateChangeThreshold(),
                breakerConfigs[b].defaultThreshold,
                "MedianDeltaBreaker default threshold mismatch"
            );
        }
    }

    // ========== BreakerBox Wiring ==========

    /// @notice BreakerBox must reference the correct SortedOracles
    function test_breakerBox_sortedOracles() public view {
        assertEq(IBreakerBox(breakerBox).sortedOracles(), sortedOracles, "BreakerBox.sortedOracles() mismatch");
    }

    /// @notice ValueDeltaBreaker must reference the correct SortedOracles
    function test_valueDeltaBreaker_wiring() public view {
        assertEq(
            IValueDeltaBreaker(valueDeltaBreaker).sortedOracles(),
            sortedOracles,
            "ValueDeltaBreaker.sortedOracles() mismatch"
        );
    }

    /// @notice MedianDeltaBreaker must reference the correct SortedOracles and BreakerBox
    function test_medianDeltaBreaker_wiring() public view {
        assertEq(
            IMedianDeltaBreaker(medianDeltaBreaker).sortedOracles(),
            sortedOracles,
            "MedianDeltaBreaker.sortedOracles() mismatch"
        );
        assertEq(
            IMedianDeltaBreaker(medianDeltaBreaker).breakerBox(), breakerBox, "MedianDeltaBreaker.breakerBox() mismatch"
        );
    }
}
