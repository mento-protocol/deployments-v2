// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {Config, IMentoConfig} from "script/config/Config.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {MockCELO} from "script/helpers/MockCELO.sol";

/**
 * @title RateFeedVerification
 * @notice Verifies that all configured rate feeds match on-chain state:
 *         - Each config rate feed has oracles registered in SortedOracles
 *         - Each config rate feed has a non-zero median rate
 *         - Each config rate feed has non-expired reports
 *         - Each FPMM pool's reference rate feed ID matches config
 *         - Chainlink relayer rate feeds have oracles registered
 *
 *         Intentionally does NOT call OracleHelper.refreshOracleRates() so we
 *         verify the actual on-chain oracle state without artificial refreshing.
 */
contract RateFeedVerification is V3IntegrationBase {
    /// @dev Grace period to account for fork staleness (fork may have been created hours ago)
    uint256 internal constant REPORT_EXPIRY_GRACE = 12 hours;

    function setUp() public override {
        // Replicate base setUp WITHOUT OracleHelper.refreshOracleRates()
        // so we test the real on-chain oracle state.
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);

        string memory namespace = vm.envOr("NAMESPACE", string("default"));
        registry = new Registry(namespace, ".treb/registry.json", ".treb/addressbook.json");

        _setDummySenderConfigs();
        config = Config.get();
        vm.selectFork(forkId);
        vm.etch(lookupOrFail("CELO"), type(MockCELO).runtimeCode);

        sortedOracles = lookupProxyOrFail("SortedOracles");
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
    }

    // ========== Config Rate Feed → On-Chain Oracle Verification ==========

    /// @notice Every rate feed in config must have at least one oracle on-chain
    function test_allConfigRateFeeds_haveOracles() public view {
        IMentoConfig.RateFeed[] memory rateFeeds = config.getRateFeeds();
        assertGt(rateFeeds.length, 0, "No rate feeds configured");

        for (uint256 i = 0; i < rateFeeds.length; i++) {
            address[] memory oracles = ISortedOracles(sortedOracles).getOracles(rateFeeds[i].rateFeedId);
            assertGt(
                oracles.length,
                0,
                string.concat(
                    "No oracles for rate feed '", rateFeeds[i].rateFeed,
                    "' (ID: ", vm.toString(rateFeeds[i].rateFeedId), ")"
                )
            );
        }
    }

    /// @notice Every rate feed in config must have a non-zero median rate on-chain
    function test_allConfigRateFeeds_haveNonZeroMedianRate() public view {
        IMentoConfig.RateFeed[] memory rateFeeds = config.getRateFeeds();
        assertGt(rateFeeds.length, 0, "No rate feeds configured");

        for (uint256 i = 0; i < rateFeeds.length; i++) {
            (uint256 rate, uint256 denominator) = ISortedOracles(sortedOracles).medianRate(rateFeeds[i].rateFeedId);
            assertGt(
                rate, 0,
                string.concat(
                    "Zero median rate for '", rateFeeds[i].rateFeed,
                    "' (ID: ", vm.toString(rateFeeds[i].rateFeedId), ")"
                )
            );
            assertGt(
                denominator, 0,
                string.concat("Zero denominator for '", rateFeeds[i].rateFeed, "'")
            );
        }
    }

    /// @notice Every rate feed in config must have non-expired reports at fork time.
    ///         Uses the fork block timestamp so test execution delay doesn't cause false failures.
    function test_allConfigRateFeeds_haveActiveReports() public view {
        IMentoConfig.RateFeed[] memory rateFeeds = config.getRateFeeds();
        assertGt(rateFeeds.length, 0, "No rate feeds configured");

        for (uint256 i = 0; i < rateFeeds.length; i++) {
            address rateFeedId = rateFeeds[i].rateFeedId;

            (, uint256[] memory timestamps,) = ISortedOracles(sortedOracles).getTimestamps(rateFeedId);
            assertGt(
                timestamps.length, 0,
                string.concat(
                    "No reports for '", rateFeeds[i].rateFeed,
                    "' (ID: ", vm.toString(rateFeedId), ")"
                )
            );

            // Oldest timestamp is the last element in the sorted list
            uint256 oldestTimestamp = timestamps[timestamps.length - 1];
            uint256 expiry = ISortedOracles(sortedOracles).getTokenReportExpirySeconds(rateFeedId);
            bool isExpired = block.timestamp > oldestTimestamp + expiry + REPORT_EXPIRY_GRACE;

            assertFalse(
                isExpired,
                string.concat(
                    "Oldest report expired for '", rateFeeds[i].rateFeed,
                    "' (ID: ", vm.toString(rateFeedId),
                    ") age=", vm.toString(block.timestamp - oldestTimestamp),
                    "s expiry=", vm.toString(expiry), "s"
                )
            );
        }
    }

    // ========== FPMM Reference Rate Feed Verification ==========

    /// @notice Every deployed FPMM pool's reference rate feed must have oracles
    function test_allFPMMPools_referenceRateFeedHasOracles() public view {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            address rateFeedId = IFPMM(pools[i]).referenceRateFeedID();
            address[] memory oracles = ISortedOracles(sortedOracles).getOracles(rateFeedId);
            assertGt(
                oracles.length, 0,
                string.concat(
                    "No oracles for FPMM pool ", vm.toString(pools[i]),
                    " referenceRateFeedID ", vm.toString(rateFeedId)
                )
            );
        }
    }

    /// @notice Every deployed FPMM pool's reference rate feed must have a non-zero rate
    function test_allFPMMPools_referenceRateFeedHasNonZeroRate() public view {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            address rateFeedId = IFPMM(pools[i]).referenceRateFeedID();
            (uint256 rate, ) = ISortedOracles(sortedOracles).medianRate(rateFeedId);
            assertGt(
                rate, 0,
                string.concat(
                    "Zero rate for FPMM pool ", vm.toString(pools[i]),
                    " referenceRateFeedID ", vm.toString(rateFeedId)
                )
            );
        }
    }

    // ========== Config ↔ On-Chain Consistency ==========

    /// @notice Each config FPMM's referenceRateFeedID must match the on-chain pool
    function test_allFPMMConfigs_rateFeedIdMatchesOnChain() public view {
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();

        for (uint256 c = 0; c < fpmmConfigs.length; c++) {
            address configToken0 = fpmmConfigs[c].token0;
            address configToken1 = fpmmConfigs[c].token1;
            address configRateFeedId = fpmmConfigs[c].referenceRateFeedID;

            bool found = false;
            for (uint256 p = 0; p < pools.length; p++) {
                IFPMM pool = IFPMM(pools[p]);
                if (pool.token0() == configToken0 && pool.token1() == configToken1) {
                    assertEq(
                        pool.referenceRateFeedID(),
                        configRateFeedId,
                        string.concat(
                            "referenceRateFeedID mismatch for pool ", vm.toString(pools[p]),
                            ": config=", vm.toString(configRateFeedId),
                            " on-chain=", vm.toString(pool.referenceRateFeedID())
                        )
                    );
                    found = true;
                    break;
                }
            }
            assertTrue(
                found,
                string.concat(
                    "Config FPMM not found on-chain: token0=", vm.toString(configToken0),
                    " token1=", vm.toString(configToken1)
                )
            );
        }
    }

    /// @notice Every chainlink relayer config's rate feed must have oracles on-chain
    function test_allChainlinkRelayerConfigs_rateFeedHasOracles() public view {
        IMentoConfig.ChainlinkRelayerConfig[] memory relayers = config.getChainlinkRelayerConfigs();
        assertGt(relayers.length, 0, "No chainlink relayer configs");

        for (uint256 i = 0; i < relayers.length; i++) {
            address[] memory oracles = ISortedOracles(sortedOracles).getOracles(relayers[i].rateFeedId);
            assertGt(
                oracles.length, 0,
                string.concat(
                    "No oracles for chainlink relayer '", relayers[i].rateFeed,
                    "' (ID: ", vm.toString(relayers[i].rateFeedId), ")"
                )
            );
        }
    }
}
