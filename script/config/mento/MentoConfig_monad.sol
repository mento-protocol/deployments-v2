// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";
import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_monad is MentoConfig {
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
            celoUsd: address(0),
            ethUsd: address(0),
            usdcUsd: 0xf5F15f188AbCB0d165D1Edb7f37F7d6fA2fCebec,
            usdtUsd: address(0),
            eurcUsd: address(0),
            ausdUsd: 0xE20751C7B5867bCBef815ffc1b284c3f412a9e13
        });

        _fxAggs = FxAggregators({
            eur: 0x00D7E359c8CE46168eFDD4D65b708fFb16c4b99a,
            brl: address(0),
            xof: address(0),
            kes: address(0),
            php: address(0),
            cop: address(0),
            ghs: address(0),
            gbp: 0x1ffC8B75a16FFfbd7879F042B580F7607Dcf5C30,
            zar: address(0),
            cad: 0x3293eA5650E9f8c4091642b7EB1C46CFEe5197cA,
            aud: address(0),
            chf: 0x6DBa7f3A7B5B7c1079337104caD14D19150F6B8d,
            jpy: 0xF64664Ea54cE47eCC7a1816C49d1Bc6deF828927,
            ngn: address(0)
        });
    }

    /// ===================================================================
    /// STABLE TOKENS
    /// ===================================================================
    function _initStables() internal virtual {
        _addStableToken("USD", "USDm", "Mento Dollar");
        _addStableToken("GBP", "GBPm", "Mento British Pound");
    }

    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal virtual {
        _addCollateral("USDC", lookup("USDC"));
        _addCollateral("AUSD", lookup("AUSD"));

        _addReserveV2Collateral("USDC");
        _addReserveV2Collateral("AUSD");
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

        LiquidityStrategyPoolConfig memory openLsConfig = LiquidityStrategyPoolConfig({
            liquidityStrategy: lookupProxy("OpenLiquidityStrategy"),
            debtToken: _lookupTokenAddress("GBPm"),
            cooldown: 300,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            liquiditySourceIncentiveExpansion: 0.0005e18,// 0.05%
            protocolIncentiveExpansion: 0,// 0%
            liquiditySourceIncentiveContraction: 0.0005e18,// 0.05%
            protocolIncentiveContraction: 0// 0%
        });

        // ── USDm / GBPm ─────────────────────────────────────────────────
        _addFPMM(
            "GBPm",
            "USDm",
            getRateFeedIdFromString("GBP/USD"),
            IFPMM.FPMMParams({
                lpFee: 10,
                protocolFee: 5,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 6,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 77_000, limit1: 385_000}),
            TokenLimits({limit0: 100_000, limit1: 500_000}),
            openLsConfig
        );

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
            TokenLimits({limit0: 2_500_000, limit1: 5_000_000}),
            TokenLimits({limit0: 2_500_000, limit1: 5_000_000}),
            usdCollateralPoolsLsConfig
        );

        // ── USDm / AUSD ────────────────────────────────────────────────
        _addFPMM(
            "USDm",
            "AUSD",
            getRateFeedIdFromString("AUSD/USD"),
            IFPMM.FPMMParams({
                lpFee: 3,
                protocolFee: 2,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 2_500_000, limit1: 5_000_000}),
            TokenLimits({limit0: 2_500_000, limit1: 5_000_000}),
            usdCollateralPoolsLsConfig
        );
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal virtual {
        _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes});
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        _addRateFeed("USDC/USD");
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

        _addRateFeed("AUSD/USD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "AUSD/USD",
            cooldown: 1,
            threshold: 0.0015 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "AUSD/USD", description: "AUSD/USD", aggregator0: _coreAggs.ausdUsd, invert0: false
        });

        _configureDefaultFxRateFeed("GBP/USD", _fxAggs.gbp);
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
