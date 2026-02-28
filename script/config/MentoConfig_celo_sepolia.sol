// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_celo_sepolia is MentoConfig {
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
        _addStableToken("USD", "cUSD", "Celo Dollar");
        _addStableToken("EUR", "cEUR", "Celo Euro");
        _addStableToken("BRL", "cREAL", "Celo Brazilian Real");
        _addStableToken("XOF", "eXOF", "ECO CFA");
        _addStableToken("KES", "cKES", "Celo Kenyan Shilling");
        _addStableToken("PHP", "PUSO", "PUSO");
        _addStableToken("COP", "cCOP", "Celo Colombian Peso");
        _addStableToken("GHS", "cGHS", "Celo Ghanaian Cedi");
        _addStableToken("GBP", "cGBP", "Celo British Pound");
        _addStableToken("ZAR", "cZAR", "Celo South African Rand");
        _addStableToken("CAD", "cCAD", "Celo Canadian Dollar");
        _addStableToken("AUD", "cAUD", "Celo Australian Dollar");
        _addStableToken("CHF", "cCHF", "Celo Swiss Franc");
        _addStableToken("JPY", "cJPY", "Celo Japanese Yen");
        _addStableToken("NGN", "cNGN", "Celo Nigerian Naira");

        _addMockCollateral("axlUSDC");
        _addMockCollateral("axlEUROC");
        _addCollateral("USDC", 0x01C5C0122039549AD1493B8220cABEdD739BC44E);
        _addCollateral("USDT", 0xd077A400968890Eacc75cdc901F0356c943e4fDb);
        _addCollateral("CELO", 0x471EcE3750Da237f93B8E339c536989b8978a438);

        ReserveLiquidityStrategyPoolConfig memory emptyRls;

        _addFPMM(
            "cUSD",
            "cGBP",
            getRateFeedIdFromString("GBPUSD"),
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

        ReserveLiquidityStrategyPoolConfig memory defaultRls = _defaultRlsConfig("cUSD");

        _addFPMM(
            "cUSD",
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
            defaultRls
        );

        _addFPMM(
            "cUSD",
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
            defaultRls
        );

        _addFPMM(
            "cUSD",
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
            defaultRls
        );
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal {
        _oracleConfig = OracleConfig({
            // XXX: testing override
            reportExpirySeconds: 2 days // 5 minutes
        });
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("celo");

        _addRateFeed("USDCUSD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDCUSD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({description: "USDCUSD", source: 0xc7A353BaE210aed958a1A2928b654938EC59DaB2});
        _addChainlinkRelayer({
            rateFeed: "USDCUSD",
            description: "USDC/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDCUSD"),
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
        _addMockAggregator({description: "USDTUSD", source: 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02});
        _addChainlinkRelayer({
            rateFeed: "USDTUSD",
            description: "USDT/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDTUSD"),
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
        _addMockAggregator({description: "EUROCUSD", source: 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd});
        // EUR/USD also added bellow
        _addChainlinkRelayer({
            rateFeed: "EUROCEUR",
            description: "EUROC/EUR",
            maxTimestampSpread: 1 days,
            aggregator0: _predict("MockChainlinkAggregator", "EUROCUSD"),
            invert0: false,
            aggregator1: _predict("MockChainlinkAggregator", "EURUSD"),
            invert1: true
        });

        _addRateFeed("CELOUSD");
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: "CELOUSD",
            cooldown: 30 minutes,
            threshold: 0.03 * 1e24,
            smoothingFactor: 1e24,
            referenceValue: 0
        });
        _addMockAggregator({description: "CELOUSD", source: 0x0568fD19986748cEfF3301e55c0eb1E729E0Ab7e});
        _addChainlinkRelayer({
            rateFeed: "CELOUSD",
            description: "CELO/USD",
            aggregator0: _predict("MockChainlinkAggregator", "CELOUSD"),
            invert0: false
        });

        _addRateFeed("CELOETH");
        _addMockAggregator({description: "ETHUSD", source: 0x1FcD30A73D67639c1cD89ff5746E7585731c083B});
        _addChainlinkRelayer({
            rateFeed: "CELOETH",
            description: "CELOETH",
            maxTimestampSpread: 10 minutes,
            aggregator0: _predict("MockChainlinkAggregator", "CELOUSD"),
            invert0: false,
            aggregator1: _predict("MockChainlinkAggregator", "ETHUSD"),
            invert1: true
        });

        _configureDefaultFxRateFeed({currency: "EUR", source: 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd});
        _configureDefaultFxRateFeed({currency: "BRL", source: 0xe8EcaF727080968Ed5F6DBB595B91e50eEb9F8B3});
        _configureDefaultFxRateFeed({currency: "XOF", source: 0x1626095f9548291cA67A6Aa743c30A1BB9380c9d});
        _configureDefaultFxRateFeed({currency: "KES", source: 0x0826492a24b1dBd1d8fcB4701b38C557CE685e9D});
        _configureDefaultFxRateFeed({currency: "PHP", source: 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c});
        _configureDefaultFxRateFeed({currency: "COP", source: 0x97b770B0200CCe161907a9cbe0C6B177679f8F7C});
        _configureDefaultFxRateFeed({currency: "GHS", source: 0x2719B648DB57C5601Bd4cB2ea934Dec6F4262cD8});
        _configureDefaultFxRateFeed({currency: "GBP", source: 0xe76FE54dfeD2ce8B4d1AC63c982DfF7CFc92bf82});
        _configureDefaultFxRateFeed({currency: "ZAR", source: 0x11b7221a0DD025778A95e9E0B87b477522C32E02});
        _configureDefaultFxRateFeed({currency: "CAD", source: 0x2f6d6cB9e01d63e1a1873BACc5BfD4e7d4e461d1});
        _configureDefaultFxRateFeed({currency: "AUD", source: 0xf2Bd4FAa89f5A360cDf118bccD183307fDBcB6F5});
        _configureDefaultFxRateFeed({currency: "CHF", source: 0xfd49bFcb3dc4aAa713c25e7d23B14BB39C4B8857});
        _configureDefaultFxRateFeed({currency: "JPY", source: 0xf323563241BF8B77a2979e9edC1181788A98EcB2});
        _configureDefaultFxRateFeed({currency: "NGN", source: 0x235e5c8697177931459fA7D19fba7256d29F17DA});

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
            aggregator0: _predict("MockChainlinkAggregator", "EURUSD"),
            invert0: false,
            aggregator1: _predict("MockChainlinkAggregator", "XOFUSD"),
            invert1: true
        });

        _addRateFeedDependency("XOFUSD", "EURXOF");
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(string memory currency, address source) internal {
        string memory rateFeed = string.concat(currency, "USD");
        _addRateFeed(rateFeed);
        _fxRateFeedIds.push(getRateFeedIdFromString(rateFeed));
        _addToBreaker({
            breakerId: medianBreakerId,
            rateFeed: rateFeed,
            cooldown: 15 minutes,
            threshold: 0.04 * 1e24,
            smoothingFactor: 0.005 * 1e24,
            referenceValue: 0
        });
        _addMockAggregator({description: rateFeed, source: source});
        _addChainlinkRelayer({
            rateFeed: rateFeed,
            description: string.concat(currency, "/USD"),
            aggregator0: _predict("MockChainlinkAggregator", rateFeed),
            invert0: false
        });

        string memory celoRateFeed = string.concat("CELO", currency);
        _addRateFeed(celoRateFeed);
        _addChainlinkRelayer({
            rateFeed: celoRateFeed,
            description: string.concat("CELO/", currency),
            maxTimestampSpread: 1 days,
            aggregator0: _predict("MockChainlinkAggregator", "CELOUSD"),
            invert0: false,
            aggregator1: _predict("MockChainlinkAggregator", rateFeed),
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
            asset0: "cUSD",
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
            asset0: "cUSD",
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
            asset0: "cUSD",
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
            asset0: "cUSD",
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
            asset0: "cEUR",
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
