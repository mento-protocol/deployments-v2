// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {MentoConfig_monad} from "./MentoConfig_monad.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_monad_testnet is MentoConfig_monad {
    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal virtual override {
        _addCollateral("USDC", lookup("USDC"));
        _registerMockCollateral("AUSD", 6);

        _addReserveV2Collateral("USDC");
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal virtual override {
        _oracleConfig = OracleConfig({
            reportExpirySeconds: 2 days // 5 minutes
        });
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("celo");

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
            label: "USDC/USD", description: "USDC/USD", source: 0xc7A353BaE210aed958a1A2928b654938EC59DaB2
        });
        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDC/USD"),
            invert0: false
        });

        _configureDefaultFxRateFeed({currency: "GBP", source: 0xe76FE54dfeD2ce8B4d1AC63c982DfF7CFc92bf82});
    }

    /// ===================================================================
    /// FPMMs
    /// ===================================================================
    function _initFPMMs() internal virtual override {
        _defaultFPMMParams = IFPMM.FPMMParams({
            lpFee: 3,
            protocolFee: 2,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            feeSetter: lookupOrFail("FeeSetter"),
            rebalanceIncentive: 1,
            rebalanceThresholdAbove: 5000,
            rebalanceThresholdBelow: 3333
        });

        ReserveLiquidityStrategyPoolConfig memory emptyRls;

        // ── USDm / GBPm ─────────────────────────────────────────────────
        _addFPMM(
            "GBPm",
            "USDm",
            getRateFeedIdFromString("GBP/USD"),
            IFPMM.FPMMParams({
                lpFee: 20,
                protocolFee: 10,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 6,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 77_000, limit1: 385_000}),
            TokenLimits({limit0: 100_000, limit1: 500_000}),
            emptyRls
        );

        // Reserve liquidity strategy params for USD collateral pools
        ReserveLiquidityStrategyPoolConfig memory usdCollateralPoolsRls = ReserveLiquidityStrategyPoolConfig({
            reserveLiquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
            debtToken: _lookupTokenAddress("USDm"),
            cooldown: 300,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            liquiditySourceIncentiveExpansion: 0,
            protocolIncentiveExpansion: 0,
            liquiditySourceIncentiveContraction: 0,
            protocolIncentiveContraction: 0
        });

        // ── USDm / USDC ────────────────────────────────────────────────
        _addFPMM(
            "USDm",
            "USDC",
            getRateFeedIdFromString("USDC/USD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 500_000, limit1: 1_000_000}),
            TokenLimits({limit0: 500_000, limit1: 1_000_000}),
            usdCollateralPoolsRls
        );
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(string memory currency, address source) internal virtual override {
        string memory rateFeed = string.concat(currency, "/USD");
        _addRateFeed(rateFeed);
        _fxRateFeedIds.push(_getRateFeedId(rateFeed));
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: rateFeed,
            cooldown: 15 minutes,
            threshold: 0.04 * 1e24,
            smoothingFactor: 0.005 * 1e24,
            referenceValue: 0
        });
        _addMockAggregator({label: rateFeed, description: rateFeed, source: source});
        _addChainlinkRelayer({
            rateFeed: rateFeed,
            description: rateFeed,
            aggregator0: _predict("MockChainlinkAggregator", rateFeed),
            invert0: false
        });
    }

    /// ===================================================================
    /// SWAP
    /// ===================================================================
    /// @notice Configure the reserve and exchange pools in the system
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
            collateralAssetDailySpendingRatios: new uint256[](0)
        });

        _addExchange({
            asset0: "USD.m",
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
            }),
            createVirtual: false
        });

        _addExchange({
            asset0: "USD.m",
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
            }),
            createVirtual: false
        });

        _addFxExchange({currency: "EUR", spread: 0.5 * 1e24, tradingLimits: _tier1FxTradingLimits(0.86 * 1e3)});
        _addFxExchange({currency: "AUD", spread: 0.15 * 1e24, tradingLimits: _tier1FxTradingLimits(1.54 * 1e3)});
        _addFxExchange({currency: "CAD", spread: 0.15 * 1e24, tradingLimits: _tier1FxTradingLimits(1.38 * 1e3)});
        _addFxExchange({currency: "GBP", spread: 0.3 * 1e24, tradingLimits: _tier1FxTradingLimits(0.75 * 1e3)});
        _addFxExchange({currency: "ZAR", spread: 0.3 * 1e24, tradingLimits: _tier1FxTradingLimits(17.72 * 1e3)});
        _addFxExchange({currency: "CHF", spread: 0.3 * 1e24, tradingLimits: _tier1FxTradingLimits(0.8 * 1e3)});
        _addFxExchange({currency: "JPY", spread: 0.3 * 1e24, tradingLimits: _tier1FxTradingLimits(149 * 1e3)});
        _addFxExchange({currency: "COP", spread: 0.3 * 1e24, tradingLimits: _tier2FxTradingLimits(4015 * 1e3)});
        _addFxExchange({currency: "BRL", spread: 0.3 * 1e24, tradingLimits: _tier1FxTradingLimits(5.45 * 1e3)});
        _addFxExchange({currency: "GHS", spread: 1.0 * 1e24, tradingLimits: _tier2FxTradingLimits(11.92 * 1e3)});
        _addFxExchange({currency: "NGN", spread: 1.0 * 1e24, tradingLimits: _tier2FxTradingLimits(1531.98 * 1e3)});
        _addFxExchange({currency: "KES", spread: 1.0 * 1e24, tradingLimits: _tier1FxTradingLimits(129.21 * 1e3)});
        _addFxExchange({currency: "PHP", spread: 1.0 * 1e24, tradingLimits: _tier1FxTradingLimits(57.4 * 1e3)});
        _addFxExchange({currency: "XOF", spread: 1.0 * 1e24, tradingLimits: _tier2FxTradingLimits(560.46 * 1e3)});
    }

    /// @notice Helper to configure an FX exchange (USD/XXX)
    /// these exchanges have simmilar settings.
    function _addFxExchange(string memory currency, uint256 spread, ExchangeTrandingLimitsConfig memory tradingLimits)
        internal
    {
        string memory asset1Symbol = _symbolForCurrency[currency];
        require(bytes(asset1Symbol).length > 0, string.concat("Currency not recoreded: ", currency));
        _addExchange({
            asset0: "USD.m",
            asset1: asset1Symbol,
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: spread,
            rateFeed: string.concat(currency, "/USD"),
            resetFrequency: 6 minutes,
            stablePoolResetSize: 10_000_000 * 1e18,
            tradingLimits: tradingLimits,
            createVirtual: false
        });
    }

    /// @notice Helper to create a tier 1 FX trading limit
    function _tier1FxTradingLimits(int48 asset1USDRate) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(100_000, 500_000, 2_500_000, asset1USDRate);
    }

    /// @notice Helper to create a tier 2 FX trading limit
    function _tier2FxTradingLimits(int48 asset1USDRate) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(50_000, 250_000, 1_250_000, asset1USDRate);
    }

    /// @notice Helper to create a two-sided trading limit
    /// where the non-USD side is computed based on the USD limit
    /// and the XXX/USD rate.
    function _fxTradingLimits(int48 limit0, int48 limit1, int48 limitGlobal, int48 asset1USDRate)
        internal
        pure
        returns (ExchangeTrandingLimitsConfig memory)
    {
        return ExchangeTrandingLimitsConfig({
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
                limit0: (limit0 * asset1USDRate) / 1000,
                timestep1: 1 days,
                limit1: (limit1 * asset1USDRate) / 1000,
                limitGlobal: (limitGlobal * asset1USDRate) / 1000,
                flags: 1 | 2 | 4
            })
        });
    }

    /// ===================================================================
    /// Governance
    /// ===================================================================
    /// @notice Configure the reserve and exchange pools in the system
    function _initGovernance() internal {
        _lockingConfig = LockingConfig({minCliffPeriod: 0, minSlopePeriod: 1});

        _governanceConfig = GovernanceConfig({
            timelockDelay: 2 days,
            votingDelay: 0,
            votingPeriod: 120_960, // XXX: Set based on blocktime
            proposalThreshold: 10000e18,
            quorum: 2,
            watchdog: address(1) // XXX: Configure
        });
    }
}
