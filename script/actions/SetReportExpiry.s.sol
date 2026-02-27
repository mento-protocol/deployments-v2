// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";

contract SetReportExpiry is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;
    using stdStorage for StdStorage;

    uint256 constant EXPIRY_SECONDS = 24 hours;

    IMentoConfig config;
    address sortedOracles;

    function setUp() public {
        config = Config.get();
        sortedOracles = lookupProxyOrFail("SortedOracles");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        IMentoConfig.ExchangeConfig[] memory exchanges = config.getExchanges();

        uint256 latestMedian;
        uint256 updated;
        for (uint256 i = 0; i < exchanges.length; i++) {
            address rateFeedId = exchanges[i].pool.config.referenceRateFeedID;

            // Track the latest median timestamp across all feeds
            uint256 medianTs = ISortedOracles(sortedOracles).medianTimestamp(
                rateFeedId
            );
            if (medianTs > latestMedian) {
                latestMedian = medianTs;
            }

            uint256 current = ISortedOracles(sortedOracles)
                .getTokenReportExpirySeconds(rateFeedId);
            if (current == EXPIRY_SECONDS) {
                continue;
            }

            stdstore
                .target(sortedOracles)
                .sig("tokenReportExpirySeconds(address)")
                .with_key(rateFeedId)
                .checked_write(EXPIRY_SECONDS);

            // Verify
            uint256 newExpiry = ISortedOracles(sortedOracles)
                .getTokenReportExpirySeconds(rateFeedId);
            require(
                newExpiry == EXPIRY_SECONDS,
                "Failed to set report expiry"
            );

            console.log(
                string.concat(
                    " > Set report expiry for ",
                    vm.toString(rateFeedId),
                    ": ",
                    vm.toString(current),
                    "s -> ",
                    vm.toString(EXPIRY_SECONDS),
                    "s"
                )
            );
            updated++;
        }

        // Warp block.timestamp to latest median so that medianReportRecent
        // passes in BiPoolManager.oracleHasValidMedian (which checks
        // medianTimestamp > now - referenceRateResetFrequency).
        if (latestMedian > 0) {
            vm.warp(latestMedian + 1);
            console.log(
                string.concat(
                    " > Warped block.timestamp to ",
                    vm.toString(latestMedian + 1),
                    " (latest median + 1)"
                )
            );
        }

        console.log(
            string.concat(
                "\n Updated ",
                vm.toString(updated),
                " rate feed(s) to ",
                vm.toString(EXPIRY_SECONDS),
                "s expiry"
            )
        );
    }
}
