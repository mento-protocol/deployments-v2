// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MentoConfig} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

contract MentoConfig_vbase is MentoConfig {
    function _initialize() internal override {
        // Add tokens
        _addToken("USDfx", "Mento Dollar");

        // Add collateral assets
        _addCollateralAsset(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC on Base

        // Oracle configuration
        _oracleConfig = OracleConfig({
            // XXX: vBase specific
            reportExpirySeconds: 30 days // 5 minutes
        });

        // BreakerBox configuration
        _breakerBoxConfig = BreakerBoxConfig({
            defaultCooldownTime: 300 // 5 minutes
        });

        // Reserve configuration
        _reserveConfig.tobinTaxStalenessThreshold = 86400; // 1 day
        _reserveConfig.spendingRatio = 1e24; // 100%
        _reserveConfig.frozenGold = 0;
        _reserveConfig.frozenDays = 0;
        _reserveConfig.assetAllocationSymbols = new bytes32[](1);
        _reserveConfig.assetAllocationSymbols[0] = bytes32("cGLD");
        _reserveConfig.assetAllocationWeights = new uint256[](1);
        _reserveConfig.assetAllocationWeights[0] = 1e24;
        _reserveConfig.tobinTax = 0;
        _reserveConfig.tobinTaxReserveRatio = 0;
        _reserveConfig.collateralAssetDailySpendingRatios = new uint256[](1);
        _reserveConfig.collateralAssetDailySpendingRatios[0] = 1e24;

        // Trading limits configuration
        _tradingLimitsConfig = TradingLimitsConfig({
            timestep0: 300, // 5 minutes
            timestep1: 86400, // 1 day
            limit0: int48(100_000e18 / 1e15), // scale down to fit int48
            limit1: int48(1_000_000e18 / 1e15), // scale down to fit int48
            limitGlobal: int48(10_000_000e18 / 1e15), // scale down to fit int48
            flags: 0x00 // All limits enabled
        });

        // Pool default configuration
        _poolDefaultConfig = PoolDefaultConfig({
            defaultSpread: 0.005e24, // 0.5%
            defaultBucketSize: 1_000_000e18,
            minimumReports: 5,
            referenceRateResetFrequency: 86400, // 1 day
            stablePoolResetSize: 1_000_000e18,
            pricingModule: "ConstantProduct"
        });

        // =============== Chainlink Relayers =============== //

        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            maxTimestampSpread: 0,
            aggregator0: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
            invert0: false
        });
    }
}
