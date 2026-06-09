// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/// @notice Debug script: iterates over the 5 rate feeds being migrated from Redstone to
///         Chainlink (USDC/USD, EUROC/EUR, CELO/USD, CELO/EUR, CELO/BRL) and prints, from
///         SortedOracles, the whitelisted oracles for each feed plus the per-oracle rates
///         currently reported on the feed.
contract PrintMigrationFeeds is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address sortedOracles;

    // Rate feed IDs of the feeds being migrated (mirrors MigrateRedstoneToChainlink).
    address[5] feeds;
    string[5] labels;

    function setUp() public {
        sortedOracles = lookupProxyOrFail("SortedOracles");

        // USDC/USD — keccak("relayed:USDCUSD")
        feeds[0] = 0xA1A8003936862E7a15092A91898D69fa8bCE290c;
        labels[0] = "USDC/USD";

        // EUROC/EUR — keccak("relayed:EUROCEUR")
        feeds[1] = 0x26076B9702885d475ac8c3dB3Bd9F250Dc5A318B;
        labels[1] = "EUROC/EUR";

        // CELO/USD — legacy: USDm proxy
        feeds[2] = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        labels[2] = "CELO/USD";

        // CELO/EUR — legacy: EURm proxy
        feeds[3] = lookupOrFail("Proxy:EURm");
        labels[3] = "CELO/EUR";

        // CELO/BRL — legacy: BRLm proxy
        feeds[4] = lookupOrFail("Proxy:BRLm");
        labels[4] = "CELO/BRL";
    }

    /// @custom:senders deployer
    function run() public broadcast {
        ISortedOracles oracles = ISortedOracles(sortedOracles);

        console.log("\n===== Migration feeds: SortedOracles state =====");
        console.log("SortedOracles:", sortedOracles);

        for (uint256 i = 0; i < feeds.length; i++) {
            address rateFeedId = feeds[i];
            string memory label = labels[i];

            console.log("\n  [%s] %s", i, label);
            console.log("    rateFeedId:", rateFeedId);

            // Whitelisted oracles for this feed.
            address[] memory whitelisted = oracles.getOracles(rateFeedId);
            console.log("    whitelisted oracle count:", whitelisted.length);
            for (uint256 j = 0; j < whitelisted.length; j++) {
                console.log("      - oracle:", whitelisted[j]);
            }

            // Per-oracle rates currently reported on the feed.
            (address[] memory rateOracles, uint256[] memory rates, ) = oracles.getRates(rateFeedId);
            console.log("    reported rate count:     ", rateOracles.length);
            for (uint256 j = 0; j < rateOracles.length; j++) {
                console.log("      - oracle:", rateOracles[j]);
                console.log("        rate:  ", rates[j]);
            }

            uint256 numRates = oracles.numRates(rateFeedId);
            if (numRates == 0) {
                console.log("    median rate: <no reports>");
                continue;
            }
            (uint256 median, uint256 denominator) = oracles.medianRate(rateFeedId);
            console.log("    median rate:", median);
            console.log("    denominator:", denominator);
        }
    }
}
