// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

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

contract DeployTokens is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;


    // Mapping to store deployed proxy addresses
    mapping(string => address) public tokenProxies;

    /**
     * @custom:senders deployer
     */
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        // Get the sender
        Senders.Sender storage deployer = sender("deployer");

        // Get the ProxyAdmin address (should be deployed already)
        address proxyAdmin = lookup("ProxyAdmin");
        require(proxyAdmin != address(0), "ProxyAdmin not deployed");

        // Get the StableTokenV2 implementation address (should be deployed with v2.6.5 label)
        address stableTokenImpl = deployer
            .create3("StableTokenV2")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false)); // disable initializers

        // Get the Broker proxy address (should be deployed already)
        address brokerProxy = lookup("TransparentUpgradeableProxy:Broker");
        require(brokerProxy != address(0), "BrokerProxy not deployed");

        // Get token configurations from config contract
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();

        // Store proxy addresses temporarily
        address[] memory proxyAddresses = new address[](tokens.length);

        // Step 1: Deploy all token proxies WITHOUT initialization
        for (uint256 i = 0; i < tokens.length; i++) {
            address proxyAddress = deployTokenProxy(
                deployer,
                tokens[i],
                stableTokenImpl,
                proxyAdmin
            );
            tokenProxies[tokens[i].symbol] = proxyAddress;
            proxyAddresses[i] = proxyAddress;
        }

        // Step 2: Initialize each token proxy (separate transactions to preserve msg.sender)
        for (uint256 i = 0; i < proxyAddresses.length; i++) {
            initializeToken(deployer, tokens[i], proxyAddresses[i]);
        }

        // Step 3: Call initializeV2 on each token with correct proxy addresses
        // Note: validators and exchange addresses are set to address(0) for now
        // These should be updated based on your deployment requirements
        for (uint256 i = 0; i < proxyAddresses.length; i++) {
            IStableTokenV2 token = IStableTokenV2(
                deployer.harness(proxyAddresses[i])
            );
            token.initializeV2(
                brokerProxy, // _broker
                address(0), // _validators (to be set based on requirements)
                address(0) // _exchange (deprecated in V2, can be 0)
            );
            console.log(
                string(abi.encodePacked(tokens[i].symbol, " initialized V2"))
            );
        }
    }


    /**
     * @notice Deploys a stable token proxy WITHOUT initialization
     */
    function deployTokenProxy(
        Senders.Sender storage deployer,
        IMentoConfig.TokenConfig memory tokenConfig,
        address implementation,
        address proxyAdmin
    ) internal returns (address) {
        // Deploy proxy without initialization data (empty bytes)
        address proxy = deployer
            .create3("TransparentUpgradeableProxy")
            .setLabel(tokenConfig.symbol)
            .deploy(
                abi.encode(
                    implementation, // implementation address
                    proxyAdmin, // admin address
                    bytes("") // NO initialization data
                )
            );

        console.log(
            string(abi.encodePacked(tokenConfig.symbol, " proxy deployed at:")),
            proxy
        );

        return proxy;
    }

    /**
     * @notice Initializes a stable token proxy (separate transaction to preserve msg.sender)
     */
    function initializeToken(
        Senders.Sender storage deployer,
        IMentoConfig.TokenConfig memory tokenConfig,
        address proxyAddress
    ) internal {
        // Prepare initialization parameters
        address[] memory initialBalanceAddresses = new address[](0);
        uint256[] memory initialBalanceValues = new uint256[](0);

        // Call initialize through harness to preserve proper msg.sender
        IStableTokenV2 token = IStableTokenV2(deployer.harness(proxyAddress));
        token.initialize(
            tokenConfig.name, // name
            tokenConfig.symbol, // symbol
            initialBalanceAddresses, // no initial balances
            initialBalanceValues // no initial balances
        );

        console.log(string(abi.encodePacked(tokenConfig.symbol, " initialized")));
    }
}
