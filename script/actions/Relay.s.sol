// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

interface IChainlinkRelayerErrors {
    error TimestampNotNew();
    error ExpiredTimestamp();
    error InvalidPrice();
    error TimestampSpreadTooHigh();
    error TooManyExistingReports();
}

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

contract Relay is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    function _logRelayError(string memory rateFeed, bytes memory reason) internal pure {
        bytes4 sel = bytes4(reason);
        if (sel == IChainlinkRelayerErrors.TimestampNotNew.selector) {
            console.log("Failed to relay %s: TimestampNotNew", rateFeed);
        } else if (sel == IChainlinkRelayerErrors.ExpiredTimestamp.selector) {
            console.log("Failed to relay %s: ExpiredTimestamp", rateFeed);
        } else if (sel == IChainlinkRelayerErrors.InvalidPrice.selector) {
            console.log("Failed to relay %s: InvalidPrice", rateFeed);
        } else if (sel == IChainlinkRelayerErrors.TimestampSpreadTooHigh.selector) {
            console.log("Failed to relay %s: TimestampSpreadTooHigh", rateFeed);
        } else if (sel == IChainlinkRelayerErrors.TooManyExistingReports.selector) {
            console.log("Failed to relay %s: TooManyExistingReports", rateFeed);
        } else {
            console.log("Failed to relay %s: unknown error", rateFeed);
            console.logBytes(reason);
        }
    }

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage deployer = sender("deployer");

        IMentoConfig.ChainlinkRelayerConfig[] memory relayerConfigs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < relayerConfigs.length; i++) {
            string memory rateFeed = relayerConfigs[i].rateFeed;
            address relayerAddy = lookupOrFail(string.concat("ChainlinkRelayerV1:", rateFeed));
            try IChainlinkRelayer(deployer.harness(relayerAddy)).relay() {
                console.log("Relayed %s", rateFeed);
            } catch (bytes memory reason) {
                _logRelayError(rateFeed, reason);
            }
        }
    }
}
