// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType, CoreAggregators, FxAggregators, Collaterals} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_celo is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;

    // Chain-specific parameters (set by _configureParams via virtual dispatch)
    string internal _rateFeedPrefix;
    address internal _gbpUsdRateFeedId;
    CoreAggregators internal _coreAggs;
    FxAggregators internal _fxAggs;
    Collaterals internal _collaterals;


    function _initialize() internal override {
        _configureParams();
        _initTokens();
        _initFPMMs();
        _initCDPMigration();
        _initOracles();
        _initSwap();
        _initGovernance();
    }

    // ===================================================================
    // Parameters (override in subclasses)
    // ===================================================================

    /// @notice Set network-specific parameters. Override in subclasses.
    function _configureParams() internal virtual {
        _rateFeedPrefix = "relayed:";
        _redemptionShortfallTolerance = 1e6;
        _gbpUsdRateFeedId = getRateFeedIdFromString("relayed:GBPUSD");

        _coreAggs = CoreAggregators({
            celoUsd: 0x0568fD19986748cEfF3301e55c0eb1E729E0Ab7e,
            ethUsd:  0x1FcD30A73D67639c1cD89ff5746E7585731c083B,
            usdcUsd: 0xc7A353BaE210aed958a1A2928b654938EC59DaB2,
            usdtUsd: 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02,
            eurcUsd: 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd
        });

        _fxAggs = FxAggregators({
            eur: 0x3D207061Dbe8E2473527611BFecB87Ff12b28dDa,
            brl: 0xe8EcaF727080968Ed5F6DBB595B91e50eEb9F8B3,
            xof: 0x1626095f9548291cA67A6Aa743c30A1BB9380c9d,
            kes: 0x0826492a24b1dBd1d8fcB4701b38C557CE685e9D,
            php: 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c,
            cop: 0x97b770B0200CCe161907a9cbe0C6B177679f8F7C,
            ghs: 0x2719B648DB57C5601Bd4cB2ea934Dec6F4262cD8,
            gbp: 0xe76FE54dfeD2ce8B4d1AC63c982DfF7CFc92bf82,
            zar: 0x11b7221a0DD025778A95e9E0B87b477522C32E02,
            cad: 0x2f6d6cB9e01d63e1a1873BACc5BfD4e7d4e461d1,
            aud: 0xf2Bd4FAa89f5A360cDf118bccD183307fDBcB6F5,
            chf: 0xfd49bFcb3dc4aAa713c25e7d23B14BB39C4B8857,
            jpy: 0xf323563241BF8B77a2979e9edC1181788A98EcB2,
            ngn: 0xc17cBE2dB40e53F4984C46F608DA6DA1fF074c11
        });

        _collaterals = Collaterals({
            usdc:     0xcebA9300f2b948710d2653dD7B07f33A8B32118C,
            axlUsdc:  0xEB466342C4d449BC9f53A865D5Cb90586f405215,
            axlEuroc: 0x061cc5a2C863E0C1Cb404006D559dB18A34C762d,
            usdt:     0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e,
            celo:     0x471EcE3750Da237f93B8E339c536989b8978a438
        });
    }

    /// ===================================================================
    /// TOKENS
    /// ===================================================================
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

        _addCollateral("USDC", _collaterals.usdc);
        _addCollateral("axlUSDC", _collaterals.axlUsdc);
        _addCollateral("axlEUROC", _collaterals.axlEuroc);
        _addCollateral("USDT", _collaterals.usdt);
        _addCollateral("CELO", _collaterals.celo);
    }

    /// ===================================================================
    /// FPMMs
    /// ===================================================================
    function _initFPMMs() internal {
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
            _gbpUsdRateFeedId,
            IFPMM.FPMMParams({
                lpFee: 20,
                protocolFee: 10,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 6,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({ limit0: 77_000, limit1: 385_000 }),
            TokenLimits({ limit0: 100_000, limit1: 500_000 }),
            emptyRls
        );

        // Reserve liquidity strategy params for USD collateral pools
        ReserveLiquidityStrategyPoolConfig memory usdCollateralPoolsRls = ReserveLiquidityStrategyPoolConfig({
            reserveLiquidityStrategy: lookupProxyOrFail("ReserveLiquidityStrategy"),
            debtToken: _lookupTokenAddress("USDm"),
            cooldown: 300,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            liquiditySourceIncentiveExpansion: 0,
            protocolIncentiveExpansion: 0,
            liquiditySourceIncentiveContraction: 0,
            protocolIncentiveContraction: 0
        });

        // ── USDm / axlUSDC ──────────────────────────────────────────────
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
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            usdCollateralPoolsRls
        );

        // ── USDm / USDC ────────────────────────────────────────────────
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
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            usdCollateralPoolsRls
        );

        // ── USDm / USDT ────────────────────────────────────────────────
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
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            TokenLimits({ limit0: 500_000, limit1: 1_000_000 }),
            usdCollateralPoolsRls
        );
    }

    /// ===================================================================
    /// CDP MIGRATION
    /// ===================================================================
    function _initCDPMigration() internal {
        _cdpMigrationConfig["GBPm"] = CDPMigrationConfig({
            collateralizationRatio: 1.7e18, // 170%
            interestRate: 0.03e18, // 3%
            stabilityPoolPercentage: 2000, // 20% in bps
            maxIterations: 500,
            cooldown: 5 minutes,
            liquiditySourceIncentiveExpansion: 0.0005e18, // 0.05%
            protocolIncentiveExpansion: 0,
            liquiditySourceIncentiveContraction: 0.0005e18, // 0.05%
            protocolIncentiveContraction: 0,
            rateFeedID: _gbpUsdRateFeedId
        });
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    function _initOracles() internal {
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        _addRateFeed("USDCUSD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDCUSD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "USDCUSD",
            description: "USDC/USD",
            aggregator0: _coreAggs.usdcUsd,
            invert0: false
        });

        _addRateFeed("USDTUSD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDTUSD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "USDTUSD",
            description: "USDT/USD",
            aggregator0: _coreAggs.usdtUsd,
            invert0: false
        });

        _addRateFeed("EUROCEUR");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "EUROCEUR",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "EUROCEUR",
            description: "EUROC/EUR",
            maxTimestampSpread: 1 days,
            aggregator0: _coreAggs.eurcUsd,
            invert0: false,
            aggregator1: _fxAggs.eur,
            invert1: true
        });

        _addRateFeed("CELOUSD", _lookupTokenAddress("USDm"));
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: "CELOUSD",
            cooldown: 30 minutes,
            threshold: 0.03 * 1e24,
            smoothingFactor: 1e24,
            referenceValue: 0
        });
        _addChainlinkRelayer({
            rateFeed: "CELOUSD",
            description: "CELO/USD",
            aggregator0: _coreAggs.celoUsd,
            invert0: false
        });

        string memory celoEthFeed = string.concat(_rateFeedPrefix, "CELOETH");
        _addRateFeed(celoEthFeed);
        _addChainlinkRelayer({
            rateFeed: celoEthFeed,
            description: "CELOETH",
            maxTimestampSpread: 10 minutes,
            aggregator0: _coreAggs.celoUsd,
            invert0: false,
            aggregator1: _coreAggs.ethUsd,
            invert1: true
        });

        // Legacy currencies: CELO cross-pair rate feed IDs are the old stable token proxy addresses
        _configureDefaultFxRateFeed("EUR", _fxAggs.eur, address(0), _lookupTokenAddress("EURm"));
        _configureDefaultFxRateFeed("BRL", _fxAggs.brl, address(0), _lookupTokenAddress("BRLm"));
        _configureDefaultFxRateFeed("XOF", _fxAggs.xof, address(0), _lookupTokenAddress("XOFm"));
        // KES: both the FX/USD feed (registered without relayed: prefix) and CELO cross-pair use non-standard IDs
        _configureDefaultFxRateFeed("KES", _fxAggs.kes, getRateFeedIdFromString("KESUSD"), _lookupTokenAddress("KESm"));
        _configureDefaultFxRateFeed({currency: "PHP", aggregator: _fxAggs.php});
        _configureDefaultFxRateFeed({currency: "COP", aggregator: _fxAggs.cop});
        _configureDefaultFxRateFeed({currency: "GHS", aggregator: _fxAggs.ghs});
        _configureDefaultFxRateFeed({currency: "GBP", aggregator: _fxAggs.gbp});
        _configureDefaultFxRateFeed({currency: "ZAR", aggregator: _fxAggs.zar});
        _configureDefaultFxRateFeed({currency: "CAD", aggregator: _fxAggs.cad});
        _configureDefaultFxRateFeed({currency: "AUD", aggregator: _fxAggs.aud});
        _configureDefaultFxRateFeed({currency: "CHF", aggregator: _fxAggs.chf});
        _configureDefaultFxRateFeed({currency: "JPY", aggregator: _fxAggs.jpy});
        _configureDefaultFxRateFeed({currency: "NGN", aggregator: _fxAggs.ngn});

        // Breakers on dependencies
        _addRateFeed("EURXOF");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "EURXOF",
            cooldown: 0,
            threshold: 0.1 * 1e24,
            smoothingFactor: 0,
            referenceValue: 655.957 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "EURXOF",
            description: "EUR/XOF",
            maxTimestampSpread: 1 days,
            aggregator0: _fxAggs.eur,
            invert0: false,
            aggregator1: _fxAggs.xof,
            invert1: true
        });

        _addRateFeedDependency(string.concat(_rateFeedPrefix, "XOFUSD"), "EURXOF");
    }

    /// @notice Configure an FX rate feed with its Chainlink relayer and CELO cross-pair.
    function _configureDefaultFxRateFeed(string memory currency, address aggregator) internal {
        _configureDefaultFxRateFeed(currency, aggregator, address(0), address(0));
    }

    /// @notice Configure an FX rate feed with explicit rate feed IDs for legacy feeds.
    /// @param fxRateFeedId If non-zero, use as the FX/USD rate feed ID instead of keccak.
    /// @param celoRateFeedId If non-zero, use as the CELO/currency rate feed ID instead of keccak.
    function _configureDefaultFxRateFeed(
        string memory currency,
        address aggregator,
        address fxRateFeedId,
        address celoRateFeedId
    ) internal {
        string memory rateFeed = string.concat(_rateFeedPrefix, currency, "USD");
        if (fxRateFeedId != address(0)) {
            _addRateFeed(rateFeed, fxRateFeedId);
        } else {
            _addRateFeed(rateFeed);
        }
        _fxRateFeedIds.push(_getRateFeedId(rateFeed));
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: rateFeed,
            cooldown: 15 minutes,
            threshold: 0.04 * 1e24,
            smoothingFactor: 0.005 * 1e24,
            referenceValue: 0
        });

        _addChainlinkRelayer({
            rateFeed: rateFeed,
            description: string.concat(currency, "/USD"),
            aggregator0: aggregator,
            invert0: false
        });

        string memory celoRateFeed = string.concat(_rateFeedPrefix, "CELO", currency);
        if (celoRateFeedId != address(0)) {
            _addRateFeed(celoRateFeed, celoRateFeedId);
        } else {
            _addRateFeed(celoRateFeed);
        }
        _addChainlinkRelayer({
            rateFeed: celoRateFeed,
            description: string.concat("CELO/", currency),
            maxTimestampSpread: 1 days,
            aggregator0: _coreAggs.celoUsd,
            invert0: false,
            aggregator1: aggregator,
            invert1: true
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
                    timestep0: 5 minutes,
                    limit0: 2_500_000,
                    timestep1: 1 days,
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
                    timestep0: 5 minutes,
                    limit0: 2_500_000,
                    timestep1: 1 days,
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
                    timestep0: 5 minutes,
                    limit0: 2_500_000,
                    timestep1: 1 days,
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

    function _tier1FxTradingLimits(int48 asset1USDRate) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(100_000, 500_000, 2_500_000, asset1USDRate);
    }

    function _tier2FxTradingLimits(int48 asset1USDRate) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(50_000, 250_000, 1_250_000, asset1USDRate);
    }

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
    function _initGovernance() internal {
        _lockingConfig = LockingConfig({minCliffPeriod: 0, minSlopePeriod: 1});
        _governanceConfig = GovernanceConfig({
            timelockDelay: 5 minutes,
            votingDelay: 0,
            votingPeriod: 10 minutes,
            proposalThreshold: 10000e18,
            quorum: 2,
            watchdog: 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81
        });
    }
}
