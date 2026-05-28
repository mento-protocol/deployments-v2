// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {IChainlinkRelayerFactory} from "mento-core/interfaces/IChainlinkRelayerFactory.sol";
import {IChainlinkRelayer} from "mento-core/interfaces/IChainlinkRelayer.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

/// @notice Debug script: iterates over all relayers deployed by the
///         ChainlinkRelayerFactory and prints each relayer's address, rate
///         feed ID, rate feed description, and the latest median price stored
///         in SortedOracles for that feed.
contract PrintRelayers is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address factory;
    address sortedOracles;

    function setUp() public {
        factory = lookupProxyOrFail("ChainlinkRelayerFactory", ProxyType.OZTUP);
        sortedOracles = lookupProxyOrFail("SortedOracles");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        address[] memory relayers = IChainlinkRelayerFactory(factory).getRelayers();
        ISortedOracles oracles = ISortedOracles(sortedOracles);

        console.log("\n===== ChainlinkRelayerFactory relayers =====");
        console.log("Factory:      ", factory);
        console.log("SortedOracles:", sortedOracles);
        console.log("Relayer count:", relayers.length);

        for (uint256 i = 0; i < relayers.length; i++) {
            IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
            address rateFeedId = relayer.rateFeedId();

            console.log("\n  [%s] %s", i, relayer.rateFeedDescription());
            console.log("    relayer:           ", relayers[i]);
            console.log("    rateFeedId:        ", rateFeedId);
            console.log("    maxTimestampSpread:", relayer.maxTimestampSpread());

            uint256 numRates = oracles.numRates(rateFeedId);
            if (numRates == 0) {
                console.log("    price:      <no reports>");
                continue;
            }

            (uint256 rate, uint256 denominator) = oracles.medianRate(rateFeedId);
            console.log("    rate:       ", rate);
            console.log("    denominator:", denominator);
        }

        console.log("\n  Printed %s relayer(s)", relayers.length);
    }
}
