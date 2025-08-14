// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

contract MentoConfig_vbase is MentoConfig {
    function _initialize() internal override {
        _addStableToken("USDfx", "Mento Dollar");
        _addCollateral("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        _addRateFeed("USDC/USD");
        console.log(_rateFeedIds.length);

        // Oracle configuration
        _oracleConfig = OracleConfig({
            // XXX: vBase specific
            reportExpirySeconds: 1 days // 5 minutes
        });

        // BreakerBox configuration
        _breakerBoxConfig = BreakerBoxConfig({
            defaultCooldownTime: 300 // 5 minutes
        });

        // Reserve configuration
        _reserveConfig = ReserveConfig({
            tobinTaxStalenessThreshold: 86400,
            spendingRatio: 1e24, // 100%
            frozenGold: 0,
            frozenDays: 0,
            assetAllocationSymbols: bytes32s(bytes32("cGLD")),
            assetAllocationWeights: uints(1e24),
            tobinTax: 0,
            tobinTaxReserveRatio: 0,
            collateralAssetDailySpendingRatios: uints(1e24)
        });

        // =============== Chainlink Relayers =============== //

        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            maxTimestampSpread: 0,
            aggregator0: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
            invert0: false
        });

        // =============== Exchanges =============== //

        _addExchange({
            asset0: "USDfx",
            asset1: "USDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.05 * 1e24,
            rateFeed: "USDC/USD",
            // XXX: vBase specific
            resetFrequency: 1 days,
            stablePoolResetSize: 1_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 300, // 5 minutes
                    timestep1: 86400, // 1 day
                    limit0: 100_000,
                    limit1: 1_000_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: emptyTradingLimits()
            })
        });
    }
}
