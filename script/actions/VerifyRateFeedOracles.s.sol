// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IChainlinkRelayerFactory} from "mento-core/interfaces/IChainlinkRelayerFactory.sol";
import {IChainlinkRelayer} from "mento-core/interfaces/IChainlinkRelayer.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

/// @notice Read-only audit: for every rate feed in the config, prints which oracles are
///         whitelisted in SortedOracles and classifies each (factory relayer for THIS feed /
///         Redstone adapter / unknown). Used to verify the Redstone -> Chainlink migration.
contract VerifyRateFeedOracles is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address constant REDSTONE_ADAPTER = 0x6490a3FFAD86CA14FF84Be380D5639Fb8fBD311B;

    IMentoConfig config;
    address sortedOracles;
    address factory;

    function setUp() public {
        config = Config.get();
        sortedOracles = lookupProxyOrFail("SortedOracles");
        factory = lookupProxyOrFail("ChainlinkRelayerFactory", ProxyType.OZTUP);
    }

    /// @custom:senders deployer
    function run() public broadcast {
        ISortedOracles oracles = ISortedOracles(sortedOracles);
        IChainlinkRelayerFactory factoryRead = IChainlinkRelayerFactory(factory);

        IMentoConfig.RateFeed[] memory feeds = config.getRateFeeds();

        console.log("\n===== Rate feed oracle audit =====");
        console.log("SortedOracles:", sortedOracles);
        console.log("Factory:      ", factory);
        console.log("Redstone:     ", REDSTONE_ADAPTER);
        console.log("Config feeds: ", feeds.length);

        uint256 feedsWithNoOracles;
        uint256 feedsAllChainlink;
        uint256 feedsWithRedstone;
        uint256 feedsWithUnknown;
        uint256 feedsMultiOracle;

        for (uint256 i = 0; i < feeds.length; i++) {
            string memory name = feeds[i].rateFeed;
            address rateFeedId = feeds[i].rateFeedId;
            address expectedRelayer = factoryRead.getRelayer(rateFeedId);
            address[] memory whitelisted = oracles.getOracles(rateFeedId);

            uint256 expiry = oracles.getTokenReportExpirySeconds(rateFeedId);

            console.log("\n  [%s] %s", i, name);
            console.log("    rateFeedId:      ", rateFeedId);
            console.log("    expected relayer:", expectedRelayer);
            console.log("    report expiry:   ", expiry);
            console.log("    oracle count:    ", whitelisted.length);

            if (whitelisted.length == 0) {
                feedsWithNoOracles++;
                console.log("    (no oracles)");
                continue;
            }

            if (whitelisted.length > 1) {
                feedsMultiOracle++;
            }

            bool sawRedstone;
            bool sawUnknown;
            bool allChainlink = true;

            for (uint256 j = 0; j < whitelisted.length; j++) {
                address o = whitelisted[j];
                string memory tag;
                if (o == expectedRelayer && o != address(0)) {
                    tag = "chainlink relayer (for this feed)";
                } else if (o == REDSTONE_ADAPTER) {
                    tag = "REDSTONE adapter";
                    sawRedstone = true;
                    allChainlink = false;
                } else {
                    tag = "UNKNOWN";
                    sawUnknown = true;
                    allChainlink = false;
                }
                console.log("      - %s : %s", o, tag);
            }

            if (sawRedstone) feedsWithRedstone++;
            if (sawUnknown) feedsWithUnknown++;
            if (allChainlink && whitelisted.length == 1) feedsAllChainlink++;
        }

        console.log("\n===== Summary =====");
        console.log("  total feeds:               ", feeds.length);
        console.log("  feeds with no oracles:     ", feedsWithNoOracles);
        console.log("  feeds Chainlink-only (1):  ", feedsAllChainlink);
        console.log("  feeds with Redstone:       ", feedsWithRedstone);
        console.log("  feeds with UNKNOWN oracle: ", feedsWithUnknown);
        console.log("  feeds with >1 oracle:      ", feedsMultiOracle);
    }
}
