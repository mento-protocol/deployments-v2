// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";

import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

interface ISortedOraclesSetter is ISortedOracles {
    function setTokenReportExpiry(address rateFeedId, uint256 expiry) external;
}

/**
 * @title SetupEuropRateFeed
 * @notice Configures the EUROP/EUR rate feed, which has no Chainlink relayer:
 *         1. Whitelists the migrationOwner as the only oracle in SortedOracles
 *         2. Sets the per-feed report expiry from config (~unlimited; the
 *            AddRateFeed script only sets expiries for relayer-backed feeds)
 *         3. Reports a fixed 1.0 rate as the migrationOwner
 *
 *         Run order: this script and AddRateFeed (BreakerBox + ValueDeltaBreaker
 *         setup for the feed) can run in either order, but both must run before
 *         CreateFPMM, which needs a valid rate to seed initial liquidity for
 *         the EURm/EUROP pool.
 *
 *         To halt trading manually (e.g. on a depeg), the migrationOwner
 *         reports a rate deviating more than the breaker threshold from 1.0;
 *         reporting 1.0 again resets the breaker after its cooldown.
 *
 *         The script is idempotent and can be re-run to refresh the report
 *         before it expires.
 */
contract SetupEuropRateFeed is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    string internal constant RATE_FEED = "EUROP/EUR";
    uint256 internal constant FIXED_RATE = 1e24; // 1.0 in SortedOracles fixidity

    /// @custom:senders migrationOwner
    function run() public broadcast {
        IMentoConfig config = Config.get();
        Senders.Sender storage migrationOwner = sender("migrationOwner");

        address sortedOraclesProxy = lookupProxyOrFail("SortedOracles");
        ISortedOraclesSetter sortedOracles = ISortedOraclesSetter(migrationOwner.harness(sortedOraclesProxy));
        ISortedOracles sortedOraclesRead = ISortedOracles(sortedOraclesProxy);

        address rateFeedId = config.getRateFeedIdFromString(RATE_FEED);

        // ── Step 1: Whitelist migrationOwner as the oracle for the feed ─────
        if (!sortedOraclesRead.isOracle(rateFeedId, migrationOwner.account)) {
            sortedOracles.addOracle(rateFeedId, migrationOwner.account);
            console.log(string.concat("Added migrationOwner as oracle for ", RATE_FEED), migrationOwner.account);
        } else {
            console.log(string.concat(unicode"  ✓ migrationOwner already an oracle for ", RATE_FEED));
        }

        // ── Step 2: Set the per-feed report expiry from config ──────────────
        uint256 expiry = config.getRateFeedExpirySeconds(RATE_FEED);
        require(expiry > 0, "EUROP/EUR report expiry not configured");
        uint256 currentExpiry = sortedOraclesRead.getTokenReportExpirySeconds(rateFeedId);
        if (currentExpiry != expiry) {
            sortedOracles.setTokenReportExpiry(rateFeedId, expiry);
            console.log(
                string.concat(
                    unicode"  ⏰ Expiry updated  [",
                    RATE_FEED,
                    "]  ",
                    vm.toString(currentExpiry),
                    "s -> ",
                    vm.toString(expiry),
                    "s"
                )
            );
        } else {
            console.log(
                string.concat(unicode"  ✓ Expiry unchanged [", RATE_FEED, "]  ", vm.toString(currentExpiry), "s")
            );
        }

        // ── Step 3: Report the fixed 1.0 rate ────────────────────────────────
        // Re-report if the median is not exactly 1.0 or the report is past
        // half its expiry window (so re-running the script refreshes it).
        (uint256 median,) = sortedOraclesRead.medianRate(rateFeedId);
        uint256 reportTs = sortedOraclesRead.medianTimestamp(rateFeedId);
        bool isFresh = reportTs + expiry / 2 > block.timestamp;
        if (median != FIXED_RATE || !isFresh) {
            sortedOracles.report(rateFeedId, FIXED_RATE, address(0), address(0));
            console.log(string.concat(unicode"  📈 Reported 1.0 rate for ", RATE_FEED));
        } else {
            console.log(string.concat(unicode"  ✓ Fresh 1.0 report already in place for ", RATE_FEED));
        }
    }
}
