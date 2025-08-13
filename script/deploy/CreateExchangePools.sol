// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IPricingModule} from "lib/mento-core/contracts/interfaces/IPricingModule.sol";
import {FixidityLib} from "@celo/common/FixidityLib.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

contract CreateExchangePools is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    struct PoolConfig {
        address asset0;  // Stable token
        address asset1;  // Collateral (CELO)
        address pricingModule;
        uint256 bucketSize0;
        uint256 bucketSize1;
        uint256 spread;
        address referenceRateFeedID;
        uint256 minimumReports;
    }

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        Senders.Sender storage deployer = sender("deployer");

        // Get deployed contracts
        address biPoolManagerProxy = lookup("TransparentUpgradeableProxy:BiPoolManager");
        require(biPoolManagerProxy != address(0), "BiPoolManager not deployed");

        // Get collateral assets from config
        IMentoConfig.CollateralAsset[] memory collateralAssets = config.getCollateralAssets();
        require(collateralAssets.length > 0, "No collateral assets configured");

        // Get pricing module based on config
        IMentoConfig.PoolDefaultConfig memory poolDefaults = config.getPoolDefaultConfig();
        address pricingModule = getPricingModuleAddress(poolDefaults.pricingModule);
        require(pricingModule != address(0), "Pricing module not deployed");

        IBiPoolManager biPoolManager = IBiPoolManager(deployer.harness(biPoolManagerProxy));

        // Create pools for all stable tokens
        PoolConfig[] memory pools = getPoolConfigs(pricingModule, config);

        for (uint256 i = 0; i < pools.length; i++) {
            IBiPoolManager.PoolExchange memory exchange = IBiPoolManager.PoolExchange({
                asset0: pools[i].asset0,
                asset1: pools[i].asset1,
                pricingModule: IPricingModule(pools[i].pricingModule),
                bucket0: pools[i].bucketSize0,
                bucket1: pools[i].bucketSize1,
                lastBucketUpdate: 0,
                config: IBiPoolManager.PoolConfig({
                    spread: FixidityLib.newFixedFraction(pools[i].spread, 1e18),
                    referenceRateFeedID: pools[i].referenceRateFeedID,
                    referenceRateResetFrequency: poolDefaults.referenceRateResetFrequency,
                    minimumReports: pools[i].minimumReports,
                    stablePoolResetSize: poolDefaults.stablePoolResetSize
                })
            });

            bytes32 exchangeId = biPoolManager.createExchange(exchange);
            
            console.log("Created exchange pool:");
            console.log("  Exchange ID:", uint256(exchangeId));
            console.log("  Stable token:", pools[i].asset0);
            console.log("  Collateral token:", pools[i].asset1);
        }
    }

    function getPoolConfigs(
        address pricingModule,
        IMentoConfig config
    ) internal view returns (PoolConfig[] memory) {
        // Get pool defaults from config
        IMentoConfig.PoolDefaultConfig memory defaults = config.getPoolDefaultConfig();
        IMentoConfig.RateFeedConfig[] memory rateFeedConfigs = config.getRateFeedConfigs();
        
        PoolConfig[] memory configs = new PoolConfig[](rateFeedConfigs.length);

        // Get collateral assets
        IMentoConfig.CollateralAsset[] memory collateralAssets = config.getCollateralAssets();
        
        for (uint256 i = 0; i < rateFeedConfigs.length; i++) {
            // Get token proxy address for asset0 (stable token)
            address asset0Proxy = lookup(string(abi.encodePacked("TransparentUpgradeableProxy:", rateFeedConfigs[i].asset0)));
            require(asset0Proxy != address(0), string(abi.encodePacked("Token not found: ", rateFeedConfigs[i].asset0)));
            
            // Get collateral address for asset1
            address asset1Address = address(0);
            
            // Check if asset1 is a stable token (look in token proxies)
            address asset1Proxy = lookup(string(abi.encodePacked("TransparentUpgradeableProxy:", rateFeedConfigs[i].asset1)));
            
            if (asset1Proxy != address(0)) {
                // asset1 is a stable token
                asset1Address = asset1Proxy;
            } else {
                // asset1 should be a collateral asset
                // For now, we'll use the first collateral asset as the default
                // In a production setup, you'd want to match based on a symbol or identifier
                require(collateralAssets.length > 0, "No collateral assets configured");
                asset1Address = collateralAssets[0].addr;
            }
            
            require(asset1Address != address(0), string(abi.encodePacked("Asset not found: ", rateFeedConfigs[i].asset1)));
            
            // Calculate rate feed ID from asset pair
            address rateFeedId = config.getRateFeedId(rateFeedConfigs[i].asset0, rateFeedConfigs[i].asset1);
            
            configs[i] = PoolConfig({
                asset0: asset0Proxy,
                asset1: asset1Address,
                pricingModule: pricingModule,
                bucketSize0: defaults.defaultBucketSize,
                bucketSize1: defaults.defaultBucketSize,
                spread: defaults.defaultSpread,
                referenceRateFeedID: rateFeedId,
                minimumReports: defaults.minimumReports
            });
        }

        return configs;
    }

    function getPricingModuleAddress(string memory moduleName) internal view returns (address) {
        if (keccak256(bytes(moduleName)) == keccak256(bytes("ConstantProduct"))) {
            return lookup("ConstantProductPricingModule:v2.6.5");
        } else if (keccak256(bytes(moduleName)) == keccak256(bytes("ConstantSum"))) {
            return lookup("ConstantSumPricingModule:v2.6.5");
        }
        return address(0);
    }
}