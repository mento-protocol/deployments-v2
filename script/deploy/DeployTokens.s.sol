// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

interface ISortedOracles {
    function setEquivalentToken(
        address token,
        address equivalentToken
    ) external;
}

// Interface for StableTokenV2 initialization
interface IStableTokenV2 {
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address[] calldata initialBalanceAddresses,
        uint256[] calldata initialBalanceValues
    ) external;

    function initializeV2(
        address _broker,
        address _validators,
        address _exchange
    ) external;
}

contract DeployTokens is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    // Mapping to store deployed proxy addresses
    mapping(string => address) public proxies;
    address broker;
    address stableTokenImpl;

    /**
     * @custom:senders deployer
     */
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();

        // Get the sender
        Senders.Sender storage deployer = sender("deployer");

        // Get the Broker proxy address (should be deployed already)
        broker = lookupProxyOrFail("Broker");
        address reserveAddy = lookupProxyOrFail("Reserve");
        IReserve reserve = IReserve(deployer.harness(reserveAddy));
        ISortedOracles sortedOracles = ISortedOracles(
            deployer.harness(lookupProxyOrFail("SortedOracles"))
        );

        // Get the StableTokenV2 implementation address (should be deployed with v2.6.5 label)
        stableTokenImpl = deployer
            .create3("StableTokenV2")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false)); // disable initializers

        // Get token configurations from config contract
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();

        // Step 1: Deploy all token proxies WITHOUT initialization
        for (uint256 i = 0; i < tokens.length; i++) {
            address proxyAddress = deployProxy(
                deployer,
                tokens[i].symbol,
                stableTokenImpl,
                bytes("") // NO initialization data
            );
            proxies[tokens[i].symbol] = proxyAddress;
        }

        // Step 2: Initialize each token proxy (separate transactions to preserve msg.sender)
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = proxies[tokens[i].symbol];
            initializeToken(deployer, tokens[i]);
            reserve.addToken(token);
            sortedOracles.setEquivalentToken(
                token,
                config.getRateFeedIdFromString(
                    string.concat("CELO/", tokens[i].currency)
                )
            );
        }
    }

    /**
     * @notice Initializes a stable token proxy (separate transaction to preserve msg.sender)
     */
    function initializeToken(
        Senders.Sender storage deployer,
        IMentoConfig.TokenConfig memory cfg
    ) internal {
        // Prepare initialization parameters
        address[] memory initialBalanceAddresses = new address[](0);
        uint256[] memory initialBalanceValues = new uint256[](0);

        // Call initialize through harness to preserve proper msg.sender
        IStableTokenV2 token = IStableTokenV2(
            deployer.harness(proxies[cfg.symbol])
        );
        token.initialize(
            cfg.name, // name
            cfg.symbol, // symbol
            initialBalanceAddresses, // no initial balances
            initialBalanceValues // no initial balances
        );
        token.initializeV2(
            broker, // _broker
            address(0), // _validators (to be set based on requirements)
            address(0) // _exchange (deprecated in V2, can be 0)
        );

        console.log(string.concat(cfg.symbol, " initialized"));
    }
}
