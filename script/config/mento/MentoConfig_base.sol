// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";
import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_base is MentoConfig {
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
            usdcUsd: address(0),
            usdtUsd: address(0),
            eurcUsd: 0xDAe398520e2B67cd3f27aeF9Cf14D93D927f8250,
            ausdUsd: address(0),
            celoUsd: address(0),
            ethUsd: address(0)
        });

        _fxAggs = FxAggregators({
            eur: 0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F,
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
        _addStableToken("EUR", "EURm", "Mento Euro");
    }

    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal virtual {
        _addCollateral("EURC", lookup("EURC"));
        _addReserveV2Collateral("EURC");
    }

    /// ===================================================================
    /// FPMMs
    /// ===================================================================
    function _initFPMMs() internal virtual {
        _defaultFPMMParams = IFPMM.FPMMParams({
            lpFee: 24,
            protocolFee: 16,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            feeSetter: lookupOrFail("FeeSetter"),
            rebalanceIncentive: 1,
            rebalanceThresholdAbove: 5000,
            rebalanceThresholdBelow: 3333
        });

        // ── EURm / EURC ──────────────────────────────────────────────
        // ReserveLiquidity strategy params for EUR collateral pools
        LiquidityStrategyPoolConfig memory eurCollateralPoolsRlsConfig = LiquidityStrategyPoolConfig({
            liquidityStrategy: lookupProxy("ReserveLiquidityStrategy"),
            debtToken: _lookupTokenAddress("EURm"),
            cooldown: 300,
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
            liquiditySourceIncentiveExpansion: 0,
            protocolIncentiveExpansion: 0,
            liquiditySourceIncentiveContraction: 0,
            protocolIncentiveContraction: 0
        });

        _addFPMM(
            "EURm",
            "EURC",
            getRateFeedIdFromString("EURC/EUR"),
            IFPMM.FPMMParams({
                lpFee: 24,
                protocolFee: 16,
                protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"),
                feeSetter: lookupOrFail("FeeSetter"),
                rebalanceIncentive: 1,
                rebalanceThresholdAbove: 5000,
                rebalanceThresholdBelow: 3333
            }),
            TokenLimits({limit0: 100_000, limit1: 500_000}),
            TokenLimits({limit0: 100_000, limit1: 500_000}),
            eurCollateralPoolsRlsConfig
        );
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    function _initOracles() internal virtual {
        _oracleConfig = OracleConfig({reportExpirySeconds: 108_000});
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        // EURC/EUR is derived from EURC/USD * USD/EUR (EUR/USD inverted).
        _addRateFeed("EURC/EUR");
        _setRateFeedExpirySeconds("EURC/EUR", 108_000);
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "EURC/EUR",
            cooldown: 1,
            threshold: 0.005 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "EURC/EUR",
            description: "EURC/EUR (EURC/USD:USD/EUR)",
            maxTimestampSpread: 1 days,
            aggregator0: _coreAggs.eurcUsd,
            invert0: false,
            aggregator1: _fxAggs.eur,
            invert1: true
        });
    }
}
