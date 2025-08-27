// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

contract MentoConfig_vbase is MentoConfig {
    function _initialize() internal override {
        // ================ Initializer Configs ============== //
        _oracleConfig = OracleConfig({
            // XXX: vBase specific
            reportExpirySeconds: 2 days // 5 minutes
        });

        _breakerBoxConfig = BreakerBoxConfig({
            defaultCooldownTime: 300 // 5 minutes
        });

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

        // =============== Tokens and ratefeeds ============= //
        _addStableToken("USDfx", "Mento US Dollar");
        _addStableToken("EURfx", "Mento EURO");
        _addStableToken("GBPfx", "Mento British Pound");
        _addStableToken("CADfx", "Mento Canadian Dollar");
        _addStableToken("AUDfx", "Mento Australian Dollar");
        _addCollateral("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        _addRateFeed("USDC/USD");
        _addRateFeed("EUR/USD");
        _addRateFeed("GBP/USD");
        _addRateFeed("CAD/USD");
        _addRateFeed("AUD/USD");

        // =============== Chainlink Relayers =============== //
        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            maxTimestampSpread: 0,
            aggregator0: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
            invert0: false
        });
        _addChainlinkRelayer({
            rateFeed: "EUR/USD",
            description: "EUR/USD",
            maxTimestampSpread: 0,
            aggregator0: 0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F,
            invert0: false
        });
        _addChainlinkRelayer({
            rateFeed: "GBP/USD",
            description: "GBP/USD",
            maxTimestampSpread: 0,
            aggregator0: 0xCceA6576904C118037695eB71195a5425E69Fa15,
            invert0: false
        });
        _addChainlinkRelayer({
            rateFeed: "CAD/USD",
            description: "CAD/USD",
            maxTimestampSpread: 0,
            aggregator0: 0xA840145F87572E82519d578b1F36340368a25D5d,
            invert0: false
        });
        _addChainlinkRelayer({
            rateFeed: "AUD/USD",
            description: "AUD/USD",
            maxTimestampSpread: 0,
            aggregator0: 0x46e51B8cA41d709928EdA9Ae43e42193E6CDf229,
            invert0: false
        });

        // =============== Exchanges =============== //
        _addExchange({
            asset0: "USDfx",
            asset1: "USDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24, // 5 bps
            rateFeed: "USDC/USD",
            // XXX: vBase specific
            resetFrequency: 2 days,
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
        _addExchange({
            asset0: "USDfx",
            asset1: "EURfx",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24, // 5 bps
            rateFeed: "EUR/USD",
            // XXX: vBase specific
            resetFrequency: 2 days,
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
        _addExchange({
            asset0: "USDfx",
            asset1: "GBPfx",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24, // 5 bps
            rateFeed: "GBP/USD",
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
        _addExchange({
            asset0: "USDfx",
            asset1: "CADfx",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24, // 5 bps
            rateFeed: "CAD/USD",
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
        _addExchange({
            asset0: "USDfx",
            asset1: "AUDfx",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24, // 5 bps
            rateFeed: "AUD/USD",
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
