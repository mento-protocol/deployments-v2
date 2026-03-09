// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

contract Relay is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage deployer = sender("deployer");

        IMentoConfig.ChainlinkRelayerConfig[] memory relayerConfigs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < relayerConfigs.length; i++) {
            address relayerAddy = lookupOrFail(string.concat("ChainlinkRelayerV1:", relayerConfigs[i].rateFeed));
            IChainlinkRelayer(deployer.harness(relayerAddy)).relay();
        }
    }
}
