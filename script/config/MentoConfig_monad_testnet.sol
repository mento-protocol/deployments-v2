// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

contract MentoConfig_monad_testnet is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;

    function _initialize() internal override {
        _initTokens();
        _initOracles();
        _initSwap();
        _initGovernance();
        _initDeployedContracts();
    }

    /// ===================================================================
    /// TOKENS
    /// ===================================================================
    /// @notice Register all stable tokens and collaterals in the system
    /// @dev On testnets we can use the _addMockCollateral to make it deploy mock
    /// collateral tokens.
    function _initTokens() internal {
        _addStableToken("USD", "USD.m", "Mento Dollar");
        _addStableToken("EUR", "EUR.m", "Mento Euro");
        _addStableToken("BRL", "BRL.m", "Mento Brazilian Real");
        _addStableToken("XOF", "XOF.m", "Mento West African CFA");
        _addStableToken("KES", "KES.m", "Mento Kenyan Shilling");
        _addStableToken("PHP", "PHP.m", "Mento Philippine Peso");
        _addStableToken("COP", "COP.m", "Mento Colombian Peso");
        _addStableToken("GHS", "GHS.m", "Mento Ghanaian Cedi");
        _addStableToken("GBP", "GBP.m", "Mento British Pound");
        _addStableToken("ZAR", "ZAR.m", "Mento South African Rand");
        _addStableToken("CAD", "CAD.m", "Mento Canadian Dollar");
        _addStableToken("AUD", "AUD.m", "Mento Australian Dollar");
        _addStableToken("CHF", "CHF.m", "Mento Swiss Franc");
        _addStableToken("JPY", "JPY.m", "Mento Japanese Yen");
        _addStableToken("NGN", "NGN.m", "Mento Nigerian Naira");

        _addCollateral("USDC", 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea);
        _addCollateral("USDT", 0x88b8E2161DEDC77EF4ab7585569D2415a1C1055D);
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
            description: "USDC/USD",
            source: 0xc7A353BaE210aed958a1A2928b654938EC59DaB2
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
            source: 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02
        });
        _addChainlinkRelayer({
            rateFeed: "USDT/USD",
            description: "USDT/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDT/USD"),
            invert0: false
        });

        _addRateFeed("EURC/EUR");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "EURC/EUR",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({
            description: "EURC/USD",
            source: 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd
        });
        // EUR/USD also added bellow
        _addChainlinkRelayer({
            rateFeed: "EURC/EUR",
            description: "EURC/EUR",
            maxTimestampSpread: 1 days,
            aggregator0: _predict("MockChainlinkAggregator", "EURC/USD"),
            invert0: false,
            aggregator1: _predict("MockChainlinkAggregator", "EUR/USD"),
            invert1: true
        });

        _configureDefaultFxRateFeed({
            currency: "EUR",
            source: 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd
        });
        _configureDefaultFxRateFeed({
            currency: "BRL",
            source: 0xe8EcaF727080968Ed5F6DBB595B91e50eEb9F8B3
        });
        _configureDefaultFxRateFeed({
            currency: "XOF",
            source: 0x1626095f9548291cA67A6Aa743c30A1BB9380c9d
        });
        _configureDefaultFxRateFeed({
            currency: "KES",
            source: 0x0826492a24b1dBd1d8fcB4701b38C557CE685e9D
        });
        _configureDefaultFxRateFeed({
            currency: "PHP",
            source: 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c
        });
        _configureDefaultFxRateFeed({
            currency: "COP",
            source: 0x97b770B0200CCe161907a9cbe0C6B177679f8F7C
        });
        _configureDefaultFxRateFeed({
            currency: "GHS",
            source: 0x2719B648DB57C5601Bd4cB2ea934Dec6F4262cD8
        });
        _configureDefaultFxRateFeed({
            currency: "GBP",
            source: 0xe76FE54dfeD2ce8B4d1AC63c982DfF7CFc92bf82
        });
        _configureDefaultFxRateFeed({
            currency: "ZAR",
            source: 0x11b7221a0DD025778A95e9E0B87b477522C32E02
        });
        _configureDefaultFxRateFeed({
            currency: "CAD",
            source: 0x2f6d6cB9e01d63e1a1873BACc5BfD4e7d4e461d1
        });
        _configureDefaultFxRateFeed({
            currency: "AUD",
            source: 0xf2Bd4FAa89f5A360cDf118bccD183307fDBcB6F5
        });
        _configureDefaultFxRateFeed({
            currency: "CHF",
            source: 0xfd49bFcb3dc4aAa713c25e7d23B14BB39C4B8857
        });
        _configureDefaultFxRateFeed({
            currency: "JPY",
            source: 0xf323563241BF8B77a2979e9edC1181788A98EcB2
        });
        _configureDefaultFxRateFeed({
            currency: "NGN",
            source: 0x235e5c8697177931459fA7D19fba7256d29F17DA
        });
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(
        string memory currency,
        address source
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
        _addMockAggregator({description: rateFeed, source: source});
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
            collateralAssetDailySpendingRatios: uints(1e24, 1e24)
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
            })
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
            })
        });

        _addFxExchange({
            currency: "EUR",
            spread: 0.50 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.86 * 1e3)
        });
        _addFxExchange({
            currency: "AUD",
            spread: 0.15 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.54 * 1e3)
        });
        _addFxExchange({
            currency: "CAD",
            spread: 0.15 * 1e24,
            tradingLimits: _tier1FxTradingLimits(1.38 * 1e3)
        });
        _addFxExchange({
            currency: "GBP",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.75 * 1e3)
        });
        _addFxExchange({
            currency: "ZAR",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(17.72 * 1e3)
        });
        _addFxExchange({
            currency: "CHF",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(0.80 * 1e3)
        });
        _addFxExchange({
            currency: "JPY",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(149 * 1e3)
        });
        _addFxExchange({
            currency: "COP",
            spread: 0.30 * 1e24,
            tradingLimits: _tier2FxTradingLimits(4015 * 1e3)
        });
        _addFxExchange({
            currency: "BRL",
            spread: 0.30 * 1e24,
            tradingLimits: _tier1FxTradingLimits(5.45 * 1e3)
        });
        _addFxExchange({
            currency: "GHS",
            spread: 1.0 * 1e24,
            tradingLimits: _tier2FxTradingLimits(11.92 * 1e3)
        });
        _addFxExchange({
            currency: "NGN",
            spread: 1.0 * 1e24,
            tradingLimits: _tier2FxTradingLimits(1531.98 * 1e3)
        });
        _addFxExchange({
            currency: "KES",
            spread: 1.0 * 1e24,
            tradingLimits: _tier1FxTradingLimits(129.21 * 1e3)
        });
        _addFxExchange({
            currency: "PHP",
            spread: 1.0 * 1e24,
            tradingLimits: _tier1FxTradingLimits(57.40 * 1e3)
        });
        _addFxExchange({
            currency: "XOF",
            spread: 1.0 * 1e24,
            tradingLimits: _tier2FxTradingLimits(560.46 * 1e3)
        });
    }

    /// @notice Helper to configure an FX exchange (USD/XXX)
    /// these exchanges have simmilar settings.
    function _addFxExchange(
        string memory currency,
        uint256 spread,
        ExchangeTrandingLimitsConfig memory tradingLimits
    ) internal {
        string memory asset1Symbol = _symbolForCurrency[currency];
        require(
            bytes(asset1Symbol).length > 0,
            string.concat("Currency not recoreded: ", currency)
        );
        _addExchange({
            asset0: "USD.m",
            asset1: asset1Symbol,
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: spread,
            rateFeed: string.concat(currency, "/USD"),
            resetFrequency: 6 minutes,
            stablePoolResetSize: 10_000_000 * 1e18,
            tradingLimits: tradingLimits
        });
    }

    /// @notice Helper to create a tier 1 FX trading limit
    function _tier1FxTradingLimits(
        int48 asset1USDRate
    ) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(100_000, 500_000, 2_500_000, asset1USDRate);
    }

    /// @notice Helper to create a tier 2 FX trading limit
    function _tier2FxTradingLimits(
        int48 asset1USDRate
    ) internal pure returns (ExchangeTrandingLimitsConfig memory) {
        return _fxTradingLimits(50_000, 250_000, 1_250_000, asset1USDRate);
    }

    /// @notice Helper to create a two-sided trading limit
    /// where the non-USD side is computed based on the USD limit
    /// and the XXX/USD rate.
    function _fxTradingLimits(
        int48 limit0,
        int48 limit1,
        int48 limitGlobal,
        int48 asset1USDRate
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

    function _initDeployedContracts() internal {
        _addDeployedContract("SortedOracles", lookupProxy("SortedOracles"));
        _addDeployedContract("BreakerBox", lookup("BreakerBox:v2.6.5"));
        _addDeployedContract("ProxyAdmin", lookup("ProxyAdmin"));
    }
}
