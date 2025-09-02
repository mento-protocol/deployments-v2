// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

contract MentoConfig_celo_sepolia is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;

    function _initialize() internal override {
        _initTokens();
        _initOracles();
        _initSwap();
        _initGovernance();
    }

    /// @notice Register all stable tokens and collateral tokens in the system
    function _initTokens() internal {
        _addStableToken("cUSD", "Celo Dollar");
        _addStableToken("cEUR", "Celo Euro");
        _addStableToken("cREAL", "Celo Brazilian Real");
        _addStableToken("eXOF", "ECO CFA");
        _addStableToken("cKES", "Celo Kenyan Shilling");
        _addStableToken("PUSO", "PUSO");
        _addStableToken("cCOP", "Celo Colombian Peso");
        _addStableToken("cGHS", "Celo Ghanaian Cedi");
        _addStableToken("cGBP", "Celo British Pound");
        _addStableToken("cZAR", "Celo South African Rand");
        _addStableToken("cCAD", "Celo Canadian Dollar");
        _addStableToken("cAUD", "Celo Australian Dollar");
        _addStableToken("cCHF", "Celo Swiss Franc");
        _addStableToken("cJPY", "Celo Japanese Yen");
        _addStableToken("cNGN", "Celo Nigerian Naira");

        _addMockCollateral("USDC");
        _addMockCollateral("USDT");
        _addMockCollateral("axlUSDC");
        _addMockCollateral("axlEUROC");
        _addCollateral("CELO", 0x471EcE3750Da237f93B8E339c536989b8978a438);
    }

    /// @notice Configure the oracle portion of the system
    function _initOracles() internal {
        _oracleConfig = OracleConfig({
            // XXX: testing override
            reportExpirySeconds: 2 days // 5 minutes
        });
        valueBreakerId = _addBreaker({
            breakerType: BreakerType.Value,
            defaultCooldownTime: 0,
            defaultThreshold: 0
        });
        medianBreakerId = _addBreaker({
            breakerType: BreakerType.Median,
            defaultCooldownTime: 0,
            defaultThreshold: 0
        });

        _addRateFeed("USDC/USD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDC/USD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({
            description: "USDC/USD",
            decimals: 18,
            initialReport: 1e18
        });
        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDC/USD"),
            invert0: false
        });

        _addRateFeed("USDT/USD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDT/USD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({
            description: "USDT/USD",
            decimals: 18,
            initialReport: 1e18
        });
        _addChainlinkRelayer({
            rateFeed: "USDT/USD",
            description: "USDT/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDT/USD"),
            invert0: false
        });

        _addRateFeed("EUROC/EUR");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "EUROC/EUR",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({
            description: "EUROC/EUR",
            decimals: 18,
            initialReport: 1e18
        });
        _addChainlinkRelayer({
            rateFeed: "EUROC/EUR",
            description: "EUROC/EUR",
            aggregator0: _predict("MockChainlinkAggregator", "EUROC/EUR"),
            invert0: false
        });

        _addRateFeed("CELO/USD");
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: "CELO/USD",
            cooldown: 30 minutes,
            threshold: 0.03 * 1e24,
            smoothingFactor: 1,
            referenceValue: 0
        });
        _addMockAggregator({
            description: "CELO/USD",
            decimals: 18,
            initialReport: 0.3131 * 1e18
        });
        _addChainlinkRelayer({
            rateFeed: "CELO/USD",
            description: "CELO/USD",
            aggregator0: _predict("MockChainlinkAggregator", "CELO/USD"),
            invert0: false
        });

        _configureDefaultFxRateFeed("EUR", 1.17000 * 1e18);
        _configureDefaultFxRateFeed("BRL", 0.18000 * 1e18);
        _configureDefaultFxRateFeed("XOF", 0.00500 * 1e18);
        _configureDefaultFxRateFeed("KES", 0.00770 * 1e18);
        _configureDefaultFxRateFeed("PHP", 0.01700 * 1e18);
        _configureDefaultFxRateFeed("COP", 0.00025 * 1e18);
        _configureDefaultFxRateFeed("GHS", 0.00500 * 1e18);
        _configureDefaultFxRateFeed("GBP", 1.35000 * 1e18);
        _configureDefaultFxRateFeed("ZAR", 0.05600 * 1e18);
        _configureDefaultFxRateFeed("CAD", 0.73000 * 1e18);
        _configureDefaultFxRateFeed("AUD", 0.65000 * 1e18);
        _configureDefaultFxRateFeed("CHF", 1.25000 * 1e18);
        _configureDefaultFxRateFeed("JPY", 0.00680 * 1e18);
        _configureDefaultFxRateFeed("NGN", 0.00065 * 1e18);
    }

    function _initSwap() internal {
        _reserveConfig = ReserveConfig({
            tobinTaxStalenessThreshold: 86400,
            spendingRatio: 1e24, // 100%
            frozenGold: 0,
            frozenDays: 0,
            assetAllocationSymbols: bytes32s(bytes32("cGLD")),
            assetAllocationWeights: uints(1e24),
            tobinTax: 0,
            tobinTaxReserveRatio: 0,
            collateralAssetDailySpendingRatios: uints(
                1e24,
                1e24,
                1e24,
                1e24,
                1e24
            )
        });

        _addExchange({
            asset0: "cUSD",
            asset1: "USDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDC/USD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes, // 5 minutes
                    limit0: 2_500_000,
                    timestep1: 1 days, // 1 day
                    limit1: 5_000_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: emptyTradingLimits()
            })
        });

        _addExchange({
            asset0: "cUSD",
            asset1: "axlUSDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDC/USD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes, // 5 minutes
                    limit0: 2_500_000,
                    timestep1: 1 days, // 1 day
                    limit1: 5_000_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: emptyTradingLimits()
            })
        });

        _addExchange({
            asset0: "cUSD",
            asset1: "USDT",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDT/USD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes, // 5 minutes
                    limit0: 2_500_000,
                    timestep1: 1 days, // 1 day
                    limit1: 5_000_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: emptyTradingLimits()
            })
        });

        _addExchange({
            asset0: "cUSD",
            asset1: "CELO",
            pricingModule: "ConstantProductPricingModule:v2.6.5",
            spread: 0.25 * 1e24,
            rateFeed: "CELO/USD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 3_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes,
                    limit0: 100_000,
                    timestep1: 1 days,
                    limit1: 500_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: emptyTradingLimits()
            })
        });

        _addFxExchange({
            currency: "AUD",
            spread: 0.15 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.6 * 1e3)
        });
        _addFxExchange({
            currency: "CAD",
            spread: 0.15 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.6 * 1e3)
        });
        _addFxExchange({
            currency: "GBP",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.6 * 1e3)
        });
        _addFxExchange({
            currency: "ZAR",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.6 * 1e3)
        });
    }

    function _addFxExchange(
        string memory currency,
        uint256 spread,
        ExchangeTrandingLimitsConfig memory tradingLimits
    ) internal {
        _addExchange({
            asset0: "cUSD",
            asset1: string.concat("c", currency),
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: spread,
            rateFeed: string.concat(currency, "/USD"),
            resetFrequency: 6 minutes,
            stablePoolResetSize: 10_000_000 * 1e18,
            tradingLimits: tradingLimits
        });
    }

    function _tier1FxTradingLimits(
        int48 asset1ScalingFactor
    ) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return
            _fxTradingLimits(100_000, 500_00, 2_500_000, asset1ScalingFactor);
    }

    function _tier2FxTradingLimits(
        int48 asset1ScalingFactor
    ) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(50_000, 250_00, 1_250_000, asset1ScalingFactor);
    }

    function _fxTradingLimits(
        int48 limit0,
        int48 limit1,
        int48 limitGlobal,
        int48 asset1ScalingFactor
    ) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return
            ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes,
                    limit0: limit0,
                    timestep1: 1 days,
                    limit1: limit1,
                    limitGlobal: limitGlobal,
                    flags: 1 | 2 | 4
                }),
                asset1: ITradingLimits.Config({
                    timestep0: 5 minutes,
                    limit0: (limit0 * asset1ScalingFactor) / 1000,
                    timestep1: 1 days,
                    limit1: (limit1 * asset1ScalingFactor) / 1000,
                    limitGlobal: (limitGlobal * asset1ScalingFactor) / 1000,
                    flags: 1 | 2 | 4
                })
            });
    }

    function _initGovernance() internal {
        _lockingConfig = LockingConfig({
            startingPointWeek: 42, // XXX: What should this be?
            minCliffPeriod: 0,
            minSlopePeriod: 1
        });

        _governanceConfig = GovernanceConfig({
            timelockDelay: 2 days,
            votingDelay: 0,
            votingPeriod: 120_960, // XXX: Set based on blocktime
            proposalThreshold: 10000e18,
            quorum: 2,
            watchdog: address(1) // XXX: Configure
        });
    }

    function _configureDefaultFxRateFeed(
        string memory currency,
        int256 initialPrice
    ) internal {
        string memory rateFeed = string.concat(currency, "/USD");
        _addRateFeed(rateFeed);
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: rateFeed,
            cooldown: 15 minutes,
            threshold: 0.04 * 1e24,
            smoothingFactor: 0.005 * 1e24,
            referenceValue: 0
        });
        _addMockAggregator({
            description: rateFeed,
            decimals: 18,
            initialReport: initialPrice
        });
        _addChainlinkRelayer({
            rateFeed: rateFeed,
            description: rateFeed,
            aggregator0: _predict("MockChainlinkAggregator", rateFeed),
            invert0: false
        });
    }
}
