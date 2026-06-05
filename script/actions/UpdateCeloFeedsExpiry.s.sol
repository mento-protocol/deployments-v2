// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

/// @dev Minimal interface for the SortedOracles report-expiry admin functions.
///      mento-core's ISortedOracles does not expose setTokenReportExpiry.
interface ISortedOraclesExpiry {
    function getTokenReportExpirySeconds(address token) external view returns (uint256);
    function setTokenReportExpiry(address token, uint256 expirySeconds) external;
}

/// @notice Updates the report expiry of all CELO/* rate feeds on Celo mainnet to 1 day + 5
///         minutes (the extra 5 minutes gives enough headroom for the report to be relayed),
///         excluding CELO/USD which intentionally stays at its existing (6 min) expiry.
/// @dev SortedOracles is owned by the MigrationMultisig, so calls are routed through the
///      `migrationOwner` sender, which queues them into a Safe transaction batch.
contract UpdateCeloFeedsExpiry is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    uint256 constant EXPIRY_SECONDS = 1 days + 5 minutes;

    IMentoConfig config;
    address sortedOracles;

    function setUp() public {
        config = Config.get();
        sortedOracles = lookupProxyOrFail("SortedOracles");
    }

    /// @custom:senders migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        ISortedOraclesExpiry sortedOraclesRead = ISortedOraclesExpiry(sortedOracles);
        ISortedOraclesExpiry sortedOraclesWrite = ISortedOraclesExpiry(owner.harness(sortedOracles));

        IMentoConfig.RateFeed[] memory feeds = config.getRateFeeds();

        console.log("\n===== Updating CELO/* rate feed report expiry (excl. CELO/USD) =====");

        uint256 updated;
        uint256 skipped;
        for (uint256 i = 0; i < feeds.length; i++) {
            if (!_isTargetFeed(feeds[i].rateFeed)) {
                continue;
            }

            address rateFeedId = feeds[i].rateFeedId;
            uint256 current = sortedOraclesRead.getTokenReportExpirySeconds(rateFeedId);

            if (current == EXPIRY_SECONDS) {
                // setTokenReportExpiry reverts if the value is unchanged, so skip.
                console.log("  Skipping %s (already %ss)", feeds[i].rateFeed, EXPIRY_SECONDS);
                skipped++;
                continue;
            }

            sortedOraclesWrite.setTokenReportExpiry(rateFeedId, EXPIRY_SECONDS);
            console.log("  Updated %s:", feeds[i].rateFeed);
            console.log("    old expiry:", current);
            console.log("    new expiry:", EXPIRY_SECONDS);
            updated++;
        }

        console.log("\n  Updated %s feed(s), skipped %s already at target", updated, skipped);

        _verify();
    }

    // ========== Verification ==========

    function _verify() internal view {
        console.log("\n===== Verification: current on-chain expiry =====");

        ISortedOraclesExpiry sortedOraclesRead = ISortedOraclesExpiry(sortedOracles);
        IMentoConfig.RateFeed[] memory feeds = config.getRateFeeds();

        for (uint256 i = 0; i < feeds.length; i++) {
            if (!_isTargetFeed(feeds[i].rateFeed)) {
                continue;
            }

            address rateFeedId = feeds[i].rateFeedId;
            uint256 onChain = sortedOraclesRead.getTokenReportExpirySeconds(rateFeedId);
            console.log("  %s: %ss", feeds[i].rateFeed, onChain);
            require(onChain == EXPIRY_SECONDS, string.concat("Verify: expiry mismatch for ", feeds[i].rateFeed));
        }

        console.log("\n  All targeted CELO/* feed expiries verified at %ss (CELO/USD excluded)", EXPIRY_SECONDS);
    }

    // ========== Helpers ==========

    /// @dev A feed is targeted if its name contains "CELO" but is not the CELO/USD feed,
    ///      which intentionally stays at its existing (6 min) expiry.
    function _isTargetFeed(string memory rateFeed) internal pure returns (bool) {
        return _contains(rateFeed, "CELO") && !_contains(rateFeed, "CELOUSD");
    }

    /// @dev Returns true if `haystack` contains `needle` as a substring (case-sensitive).
    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) {
            return false;
        }

        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) {
                return true;
            }
        }
        return false;
    }
}
