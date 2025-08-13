// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

contract ConfigureBrokerExchangeProviders is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        Senders.Sender storage deployer = sender("deployer");

        // Get deployed contracts
        address brokerProxy = lookup("TransparentUpgradeableProxy:Broker");
        require(brokerProxy != address(0), "Broker not deployed");

        address biPoolManagerProxy = lookup("TransparentUpgradeableProxy:BiPoolManager");
        require(biPoolManagerProxy != address(0), "BiPoolManager not deployed");

        address reserveProxy = lookup("TransparentUpgradeableProxy:Reserve");
        require(reserveProxy != address(0), "Reserve not deployed");

        IBroker broker = IBroker(deployer.harness(brokerProxy));

        // Add BiPoolManager as an exchange provider
        broker.addExchangeProvider(biPoolManagerProxy, reserveProxy);
        console.log("Added BiPoolManager as exchange provider");

        // Get all exchange IDs from BiPoolManager and configure trading limits
        IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
        bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();
        
        // Configure trading limits for each exchange
        for (uint256 i = 0; i < exchangeIds.length; i++) {
            configureTradingLimits(deployer, brokerProxy, exchangeIds[i], config);
        }
    }

    function configureTradingLimits(
        Senders.Sender storage deployer,
        address brokerProxy,
        bytes32 exchangeId,
        IMentoConfig config
    ) internal {
        IBroker broker = IBroker(deployer.harness(brokerProxy));

        // Get trading limits configuration from config contract
        IMentoConfig.TradingLimitsConfig memory limitsConfig = config.getTradingLimitsConfig();
        
        ITradingLimits.Config memory tradingConfig = ITradingLimits.Config({
            timestep0: limitsConfig.timestep0,
            timestep1: limitsConfig.timestep1,
            limit0: limitsConfig.limit0,
            limit1: limitsConfig.limit1,
            limitGlobal: limitsConfig.limitGlobal,
            flags: limitsConfig.flags
        });

        // Get all token addresses
        address[] memory tokenAddresses = getTokenAddresses(config);

        // Configure limits for each token
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            broker.configureTradingLimit(
                exchangeId,
                tokenAddresses[i],
                tradingConfig
            );
            console.log("Configured trading limits for token", tokenAddresses[i]);
        }
    }

    function getTokenAddresses(IMentoConfig config) internal view returns (address[] memory) {
        IMentoConfig.TokenConfig[] memory tokenConfigs = config.getTokenConfigs();
        address[] memory tokens = new address[](tokenConfigs.length);
        
        for (uint256 i = 0; i < tokenConfigs.length; i++) {
            tokens[i] = lookup(string(abi.encodePacked("TransparentUpgradeableProxy:", tokenConfigs[i].symbol)));
        }
        
        return tokens;
    }
}