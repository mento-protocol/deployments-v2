// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";
import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_polygon is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;
    CoreAggregators internal _coreAggs;
    FxAggregators internal _fxAggs;

    function _initialize() internal virtual override {
        _configureParams();
        _initStables();
        _initCollateral();
        _initFPMMs();
        _initOracles();
    }

    // ===================================================================
    // Parameters (override in subclasses)
    // ===================================================================
    /// @notice Set network-specific parameters. Override in subclasses.
    function _configureParams() internal virtual {
        _coreAggs = CoreAggregators({
            usdcUsd: 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7,
            usdtUsd: address(0),
            eurcUsd: address(0),
            ausdUsd: address(0),
            celoUsd: address(0),
            ethUsd: address(0)
        });

        _fxAggs = FxAggregators({
            eur: 0x73366Fe0AA0Ded304479862808e02506FE556a98,
            brl: address(0),
            xof: address(0),
            kes: address(0),
            php: address(0),
            cop: address(0),
            ghs: address(0),
            gbp: address(0),
            zar: address(0),
            cad: address(0),
            aud: address(0),
            chf: address(0),
            jpy: address(0),
            ngn: address(0)
        });
    }

    /// ===================================================================
    /// STABLE TOKENS
    /// ===================================================================
    function _initStables() internal virtual {
        _addStableToken("USD", "USDm", "Mento Dollar");
        _addStableToken("EUR", "EURm", "Mento Euro");
    }

    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal virtual {
        _addCollateral("USDC", lookupOrFail("USDC"));
        _addReserveV2Collateral("USDC");
    }

    /// ===================================================================
    /// FPMMs
    /// ===================================================================
    function _initFPMMs() internal virtual {
        _defaultFPMMParams = IFPMM.FPMMParams({
            lpFee: 3,
            protocolFee: 2,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            feeSetter: lookupOrFail("FeeSetter"),
            rebalanceIncentive: 1,
            rebalanceThresholdAbove: 5000,
            rebalanceThresholdBelow: 3333
        });

        // Liquidity strategy params for USD collateral pools
        LiquidityStrategyPoolConfig memory usdCollateralPoolsLsConfig = LiquidityStrategyPoolConfig({
            liquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
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
            usdCollateralPoolsLsConfig
        );

        // ── USDm / EURm ────────────────────────────────────────────────
        LiquidityStrategyPoolConfig memory openLsConfigEUR = LiquidityStrategyPoolConfig({
            liquidityStrategy: lookupProxy("OpenLiquidityStrategy"),
            debtToken: _lookupTokenAddress("USDm"),
            cooldown: 300,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            liquiditySourceIncentiveExpansion: 0.0002e18, // 2bps / 0.02%
            protocolIncentiveExpansion: 0, // 0%
            liquiditySourceIncentiveContraction: 0.0002e18, // 2bps / 0.02%
            protocolIncentiveContraction: 0 // 0%
        });

        _addFPMM(
            "EURm",
            "USDm",
            getRateFeedIdFromString("EUR/USD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 3,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 215_000, limit1: 860_000}),
            TokenLimits({limit0: 250_000, limit1: 1_000_000}),
            openLsConfigEUR
        );
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal virtual {
        _oracleConfig = OracleConfig({reportExpirySeconds: 150 seconds}); // TODO: find a place where to detect updates made to this value other than AddRateFeeds.s.sol
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        _addRateFeed("USDC/USD");
        _setRateFeedExpirySeconds("USDC/USD", 150 seconds);
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "USDC/USD",
            cooldown: 1,
            threshold: 0.0015 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "USDC/USD", description: "USDC/USD", aggregator0: _coreAggs.usdcUsd, invert0: false
        });

        _configureDefaultFxRateFeed("EUR/USD", _fxAggs.eur);
        _setRateFeedExpirySeconds("EUR/USD", 150 seconds);
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(string memory rateFeed, address source) internal virtual {
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
        _addChainlinkRelayer({rateFeed: rateFeed, description: rateFeed, aggregator0: source, invert0: false});
    }
}
