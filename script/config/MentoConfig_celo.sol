// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_celo is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;

    function _initialize() internal override {
        _initTokens();
        _initOracles();
        _initSwap();
        _initGovernance();
    }

    /// ===================================================================
    /// TOKENS
    /// ===================================================================
    /// @notice Register all stable tokens and collaterals in the system
    /// @dev On testnets we can use the _addMockCollateral to make it deploy mock
    /// collateral tokens.
    function _initTokens() internal {
        _addStableToken("USD", "USDm", "Celo Dollar");
        _addStableToken("EUR", "EURm", "Celo Euro");
        _addStableToken("BRL", "BRLm", "Celo Brazilian Real");
        _addStableToken("XOF", "XOFm", "ECO CFA");
        _addStableToken("KES", "KESm", "Celo Kenyan Shilling");
        _addStableToken("PHP", "PHPm", "PUSO");
        _addStableToken("COP", "COPm", "Celo Colombian Peso");
        _addStableToken("GHS", "GHSm", "Celo Ghanaian Cedi");
        _addStableToken("GBP", "GBPm", "Celo British Pound");
        _addStableToken("ZAR", "ZARm", "Celo South African Rand");
        _addStableToken("CAD", "CADm", "Celo Canadian Dollar");
        _addStableToken("AUD", "AUDm", "Celo Australian Dollar");
        _addStableToken("CHF", "CHFm", "Celo Swiss Franc");
        _addStableToken("JPY", "JPYm", "Celo Japanese Yen");
        _addStableToken("NGN", "NGNm", "Celo Nigerian Naira");

        _addCollateral("USDC", 0xcebA9300f2b948710d2653dD7B07f33A8B32118C);
        _addCollateral("axlUSDC", 0xEB466342C4d449BC9f53A865D5Cb90586f405215);
        _addCollateral("axlEUROC", 0x061cc5a2C863E0C1Cb404006D559dB18A34C762d);
        _addCollateral("USDT", 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e);
        _addCollateral("CELO", 0x471EcE3750Da237f93B8E339c536989b8978a438);

        ReserveLiquidityStrategyPoolConfig memory emptyRls;

        _addFPMM(
            "USDm",
            "GBPm",
            getRateFeedIdFromString("relayed:GBPUSD"),
            IFPMM.FPMMParams({
                lpFee: 10,
                protocolFee: 5,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 6,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            emptyRls
        );

        _addFPMM(
            "USDm",
            "axlUSDC",
            getRateFeedIdFromString("USDCUSD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            ReserveLiquidityStrategyPoolConfig({
                reserveLiquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
                debtToken: _lookupTokenAddress("USDm"),
                cooldown: 300,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                liquiditySourceIncentiveExpansion: 0,
                protocolIncentiveExpansion: 0,
                liquiditySourceIncentiveContraction: 0,
                protocolIncentiveContraction: 0
            })
        );

        _addFPMM(
            "USDm",
            "USDC",
            getRateFeedIdFromString("USDCUSD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            ReserveLiquidityStrategyPoolConfig({
                reserveLiquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
                debtToken: _lookupTokenAddress("USDm"),
                cooldown: 300,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                liquiditySourceIncentiveExpansion: 0,
                protocolIncentiveExpansion: 0,
                liquiditySourceIncentiveContraction: 0,
                protocolIncentiveContraction: 0
            })
        );

        _addFPMM(
            "USDm",
            "USDT",
            getRateFeedIdFromString("USDTUSD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            ReserveLiquidityStrategyPoolConfig({
                reserveLiquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
                debtToken: _lookupTokenAddress("USDm"),
                cooldown: 300,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                liquiditySourceIncentiveExpansion: 0,
                protocolIncentiveExpansion: 0,
                liquiditySourceIncentiveContraction: 0,
                protocolIncentiveContraction: 0
            })
        );
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal {}

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
            collateralAssetDailySpendingRatios: uints(1e24, 1e24, 1e24, 1e24, 1e24)
        });

        _addExchange({
            asset0: "USDm",
            asset1: "USDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDCUSD",
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
            asset0: "USDm",
            asset1: "axlUSDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDCUSD",
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
            asset0: "USDm",
            asset1: "USDT",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0,
            rateFeed: "USDTUSD",
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
            asset0: "USDm",
            asset1: "CELO",
            pricingModule: "ConstantProductPricingModule:v2.6.5",
            spread: 0.0025 * 1e24,
            rateFeed: "CELOUSD",
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
            }),
            createVirtual: false
        });

        _addExchange({
            asset0: "EURm",
            asset1: "axlEUROC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.005 * 1e24,
            rateFeed: "EUROCEUR",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTrandingLimitsConfig({
                asset0: ITradingLimits.Config({
                    timestep0: 5 minutes,
                    limit0: 100_000,
                    timestep1: 1 days,
                    limit1: 500_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                }),
                asset1: ITradingLimits.Config({
                    timestep0: 5 minutes,
                    limit0: 100_000,
                    timestep1: 1 days,
                    limit1: 500_000,
                    limitGlobal: 0,
                    flags: 1 | 2
                })
            }),
            createVirtual: false
        });

        _addFxExchange({
            currency: "EUR",
            spread: 0.0050 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.86 * 1e3),
            createVirtual: false
        });
        _addFxExchange({
            currency: "AUD",
            spread: 0.0015 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.54 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "CAD",
            spread: 0.0015 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.38 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "GBP",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.75 * 1e3),
            createVirtual: false
        });
        _addFxExchange({
            currency: "ZAR",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier1FxTradingLimits(17.72 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "CHF",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.80 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "JPY",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier1FxTradingLimits(149 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "COP",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier2FxTradingLimits(4015 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "BRL",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier1FxTradingLimits(5.45 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "PHP",
            spread: 0.0030 * 1e24,
            tradingLimits: _tier2FxTradingLimits(57.40 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "GHS",
            spread: 0.0100 * 1e24,
            tradingLimits: _tier2FxTradingLimits(11.92 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "NGN",
            spread: 0.0100 * 1e24,
            tradingLimits: _tier2FxTradingLimits(1531.98 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "KES",
            spread: 0.0100 * 1e24,
            tradingLimits: _tier1FxTradingLimits(129.21 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "XOF",
            spread: 0.0200 * 1e24,
            tradingLimits: _tier2FxTradingLimits(560.46 * 1e3),
            createVirtual: true
        });
    }

    /// @notice Helper to configure an FX exchange (USD/XXX)
    /// these exchanges have simmilar settings.
    function _addFxExchange(
        string memory currency,
        uint256 spread,
        ExchangeTrandingLimitsConfig memory tradingLimits,
        bool createVirtual
    ) internal {
        _addExchange({
            asset0: _symbolForCurrency["USD"],
            asset1: _symbolForCurrency[currency],
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: spread,
            rateFeed: string.concat(currency, "USD"),
            resetFrequency: 6 minutes,
            stablePoolResetSize: 10_000_000 * 1e18,
            tradingLimits: tradingLimits,
            createVirtual: createVirtual
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
    /// @notice Configure the governance params
    function _initGovernance() internal {
        _lockingConfig = LockingConfig({minCliffPeriod: 0, minSlopePeriod: 1});
        _governanceConfig = GovernanceConfig({
            timelockDelay: 5 minutes,
            votingDelay: 0,
            votingPeriod: 10 minutes, // 1 block ~= 1 second
            proposalThreshold: 10000e18,
            quorum: 2,
            watchdog: 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81 // Mento Deployer
        });
    }
}
