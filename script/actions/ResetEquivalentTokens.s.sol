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

interface ISortedOracles {
    function setEquivalentToken(
        address token,
        address equivalentToken
    ) external;
}

contract ResetEquivalentTokens is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage deployer = sender("deployer");
        ISortedOracles sortedOracles = ISortedOracles(
            deployer.harness(lookupProxyOrFail("SortedOracles"))
        );

        // Get token configurations from config contract
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = lookupProxyOrFail(tokens[i].symbol);
            sortedOracles.setEquivalentToken(
                token,
                config.getRateFeedIdFromString(
                    string.concat("CELO", tokens[i].currency)
                )
            );
        }
    }
}
