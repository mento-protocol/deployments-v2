// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MentoConfig, ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {MentoConfig_celo} from "./MentoConfig_celo.sol";
import {CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {bytes32s, uints} from "lib/mento-std/src/Array.sol";

contract MentoConfig_celo_sepolia is MentoConfig_celo {
    // ===================================================================
    // Parameters (sepolia overrides)
    // ===================================================================

    /// @dev On Sepolia, mock aggregators were deployed with old-format labels (no slashes).
    ///      The test namespace differs from the deployment namespace, so _predict returns
    ///      wrong addresses. Use registry lookup (same pattern as _registerMockCollateral).
    function _mockAggregator(string memory label, string memory description, address source)
        internal
        override
        returns (address)
    {
        _addMockAggregator(label, description, source);
        address addy = lookup(string.concat("MockChainlinkAggregator:", label));
        if (addy == address(0)) {
            addy = _predict("MockChainlinkAggregator", label);
        }
        return addy;
    }

    function _configureParams() internal override {
        super._configureParams();

        _rateFeedPrefix = "";
        _useLegacyRateFeedIds = false;
        _gbpUsdRateFeedId = getRateFeedIdFromString("GBPUSD");
        _eurUsdRateFeedId = getRateFeedIdFromString("EURUSD");
        _jpyUsdRateFeedId = getRateFeedIdFromString("JPYUSD");
        _chfUsdRateFeedId = getRateFeedIdFromString("CHFUSD");

        // Oracle infrastructure
        _oracleConfig = OracleConfig({reportExpirySeconds: 5 minutes});
        _eurocEurBreakerThreshold = 0.001 * 1e24;
        _celoEthRelayerMaxTimestampSpread = 10 minutes;
        _celoEthRelayerDescription = "CELOETH";
        _includeCollateralRelayers = true;
        _useLongCrossPairDesc = false;
        _includeCeloUsdRelayer = true;
        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("celo");

        // Wrap FX aggregators in mocks (before _coreAggs so we can reference source addresses)
        // Labels must match what was deployed (old-format) to produce correct CREATE3 addresses
        _fxAggs = FxAggregators({
            eur: _mockAggregator("EURUSD", "EUR/USD", _coreAggs.eurcUsd), // No EUR/USD on sepolia, use EURC/USD
            brl: _mockAggregator("BRLUSD", "BRL/USD", _fxAggs.brl),
            xof: _mockAggregator("XOFUSD", "XOF/USD", _fxAggs.xof),
            kes: _mockAggregator("KESUSD", "KES/USD", _fxAggs.kes),
            php: _mockAggregator("PHPUSD", "PHP/USD", _fxAggs.php),
            cop: _mockAggregator("COPUSD", "COP/USD", _fxAggs.cop),
            ghs: _mockAggregator("GHSUSD", "GHS/USD", _fxAggs.ghs),
            gbp: _mockAggregator("GBPUSD", "GBP/USD", _fxAggs.gbp),
            zar: _mockAggregator("ZARUSD", "ZAR/USD", _fxAggs.zar),
            cad: _mockAggregator("CADUSD", "CAD/USD", _fxAggs.cad),
            aud: _mockAggregator("AUDUSD", "AUD/USD", _fxAggs.aud),
            chf: _mockAggregator("CHFUSD", "CHF/USD", _fxAggs.chf),
            jpy: _mockAggregator("JPYUSD", "JPY/USD", _fxAggs.jpy),
            ngn: _mockAggregator("NGNUSD", "NGN/USD", 0x235e5c8697177931459fA7D19fba7256d29F17DA) // Different source on sepolia
        });

        // Wrap core aggregators in mocks
        _coreAggs = CoreAggregators({
            celoUsd: _mockAggregator("CELOUSD", "CELO/USD", _coreAggs.celoUsd),
            ethUsd: _mockAggregator("ETHUSD", "ETH/USD", _coreAggs.ethUsd),
            usdcUsd: _mockAggregator("USDCUSD", "USDC/USD", _coreAggs.usdcUsd),
            usdtUsd: _mockAggregator("USDTUSD", "USDT/USD", _coreAggs.usdtUsd),
            eurcUsd: _mockAggregator("EUROCUSD", "EURC/USD", _coreAggs.eurcUsd),
            ausdUsd: address(0)
        });
    }

    function _initReserve() internal override {
        _reserveConfig = ReserveConfig({
            tobinTaxStalenessThreshold: 86400, // 1 day
            spendingRatio: 1e24, // 100%
            frozenGold: 0,
            frozenDays: 0,
            assetAllocationSymbols: bytes32s(bytes32("cGLD")),
            assetAllocationWeights: uints(1e24),
            tobinTax: 0,
            tobinTaxReserveRatio: 0,
            collateralAssetDailySpendingRatios: new uint256[](0)
        });
    }

    function _initSwap() internal override {
        _addExchange({
            asset0: "USDm",
            asset1: "USDC",
            pricingModule: "ConstantSumPricingModule:v2.6.5",
            spread: 0.0005 * 1e24,
            rateFeed: "USDCUSD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTradingLimitsConfig({
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
            spread: 0.0005 * 1e24,
            rateFeed: "USDCUSD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTradingLimitsConfig({
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
            spread: 0.0005 * 1e24,
            rateFeed: "USDTUSD",
            resetFrequency: 6 minutes,
            stablePoolResetSize: 12_000_000 * 1e18,
            tradingLimits: ExchangeTradingLimitsConfig({
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
            tradingLimits: ExchangeTradingLimitsConfig({
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
            tradingLimits: ExchangeTradingLimitsConfig({
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
            spread: 0.005 * 1e24,
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
            currency: "ZAR",
            spread: 0.003 * 1e24,
            tradingLimits: _fxTradingLimits(100_000, 500_000, 2_500_000, 17.72 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "COP",
            spread: 0.003 * 1e24,
            tradingLimits: _tier2FxTradingLimits(4015.0 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "BRL", spread: 0.003 * 1e24, tradingLimits: _tier1FxTradingLimits(5.45 * 1e3), createVirtual: true
        });
        _addFxExchange({
            currency: "PHP", spread: 0.003 * 1e24, tradingLimits: _tier2FxTradingLimits(57.4 * 1e3), createVirtual: true
        });
        _addFxExchange({
            currency: "GHS", spread: 0.01 * 1e24, tradingLimits: _tier2FxTradingLimits(11.92 * 1e3), createVirtual: true
        });
        _addFxExchange({
            currency: "NGN",
            spread: 0.01 * 1e24,
            tradingLimits: _tier2FxTradingLimits(1531.98 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "KES",
            spread: 0.01 * 1e24,
            tradingLimits: _tier1FxTradingLimits(129.21 * 1e3),
            createVirtual: true
        });
        _addFxExchange({
            currency: "XOF",
            spread: 0.02 * 1e24,
            tradingLimits: _fxTradingLimits(50_000, 250_000, 1_250_000, 560.46 * 1e3),
            createVirtual: true
        });
    }

    function _initCollateral() internal override {
        _addCollateral("USDC", 0x01C5C0122039549AD1493B8220cABEdD739BC44E);
        _addCollateral("axlUSDC", _registerMockCollateral("axlUSDC", 18));
        _addCollateral("axlEUROC", _registerMockCollateral("axlEUROC", 18));
        _addCollateral("USDT", 0xd077A400968890Eacc75cdc901F0356c943e4fDb);
        _addCollateral("CELO", lookupOrFail("CELO"));

        // TODO: set spending ratios on-chain for USDC and USDT (currently 0)
        // _setCollateralSpendingLimit("USDC", 1e24);
        // _setCollateralSpendingLimit("USDT", 1e24);
        _setCollateralSpendingLimit("axlUSDC", 1e24);
        _setCollateralSpendingLimit("axlEUROC", 1e24);
        _setCollateralSpendingLimit("CELO", 1e24);

        // ReserveV2 collateral registration
        _addReserveV2Collateral("USDC");
        _addReserveV2Collateral("USDT");
        _addReserveV2Collateral("axlUSDC");
        // TODO: register in ReserveV2 on-chain
        // _addReserveV2Collateral("axlEUROC");
        // _addReserveV2Collateral("CELO");
    }

    function _initGovernance() internal override {
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
