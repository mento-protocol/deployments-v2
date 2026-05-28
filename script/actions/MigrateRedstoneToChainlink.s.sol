// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IChainlinkRelayerFactory} from "mento-core/interfaces/IChainlinkRelayerFactory.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

/// @notice One-off migration: removes the Redstone adapter from the 5 rate feeds that were
///         previously Redstone-only (USDC/USD, EUROC/EUR, CELO/USD, CELO/EUR, CELO/BRL).
///         Run AFTER DeployChainlinkRelayers, which deploys the new Chainlink relayers and
///         adds each as a second oracle, so each feed enters this script with
///         [Redstone @ index 0, Chainlink @ index 1]. This script removes Redstone at
///         index 0, leaving the Chainlink relayer as the sole oracle.
contract MigrateRedstoneToChainlink is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address constant REDSTONE_ADAPTER = 0x6490a3FFAD86CA14FF84Be380D5639Fb8fBD311B;

    address sortedOracles;
    address factory;

    // Rate feed IDs of the feeds being migrated (legacy stable-token proxy addresses on mainnet).
    address[5] feeds;
    string[5] labels;

    function setUp() public {
        sortedOracles = lookupProxyOrFail("SortedOracles");
        factory = lookupProxyOrFail("ChainlinkRelayerFactory", ProxyType.OZTUP);

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

    /// @custom:senders migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        ISortedOracles sortedOraclesRead = ISortedOracles(sortedOracles);
        ISortedOracles sortedOraclesWrite = ISortedOracles(owner.harness(sortedOracles));
        IChainlinkRelayerFactory factoryRead = IChainlinkRelayerFactory(factory);

        console.log("\n===== Migrate Redstone -> Chainlink (5 feeds) =====");
        console.log("SortedOracles:", sortedOracles);
        console.log("Factory:      ", factory);
        console.log("Redstone:     ", REDSTONE_ADAPTER);

        for (uint256 i = 0; i < feeds.length; i++) {
            address rateFeedId = feeds[i];
            string memory label = labels[i];

            console.log("\n  [%s] %s", i, label);
            console.log("    rateFeedId:", rateFeedId);

            // 1. Look up the Chainlink relayer for this feed (must already be deployed).
            address chainlinkRelayer = factoryRead.getRelayer(rateFeedId);
            require(chainlinkRelayer != address(0), string.concat("No Chainlink relayer deployed for ", label));

            // 2. Assert oracle state: exactly [Redstone @ 0, Chainlink @ 1].
            address[] memory oracles = sortedOraclesRead.getOracles(rateFeedId);
            require(oracles.length == 2, string.concat("Expected 2 oracles for ", label));
            require(oracles[0] == REDSTONE_ADAPTER, string.concat("Expected Redstone at index 0 for ", label));
            require(oracles[1] == chainlinkRelayer, string.concat("Expected Chainlink at index 1 for ", label));

            console.log("    redstone (idx 0):  ", REDSTONE_ADAPTER);
            console.log("    chainlink (idx 1): ", chainlinkRelayer);

            // 3. Remove the Redstone adapter at index 0, leaving Chainlink as the sole oracle.
            sortedOraclesWrite.removeOracle(rateFeedId, REDSTONE_ADAPTER, 0);
        }

        _verify(sortedOraclesRead, factoryRead);
    }

    function _verify(ISortedOracles sortedOraclesRead, IChainlinkRelayerFactory factoryRead) internal view {
        console.log("\n===== Verification =====");

        for (uint256 i = 0; i < feeds.length; i++) {
            address rateFeedId = feeds[i];
            string memory label = labels[i];
            address expectedRelayer = factoryRead.getRelayer(rateFeedId);

            address[] memory oracles = sortedOraclesRead.getOracles(rateFeedId);
            require(oracles.length == 1, string.concat("Verify: expected 1 oracle for ", label));
            require(oracles[0] == expectedRelayer, string.concat("Verify: unexpected oracle for ", label));

            console.log("  %s -> %s", label, oracles[0]);
        }

        console.log("\n  All 5 feeds migrated to their Chainlink relayers");
    }
}
