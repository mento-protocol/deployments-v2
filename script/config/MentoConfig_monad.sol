// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {MentoConfig, ITradingLimits, BreakerType} from "./MentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

contract MentoConfig_monad is MentoConfig {
    bytes32 internal valueBreakerId;
    bytes32 internal medianBreakerId;

    function _initialize() internal virtual override {
        _initTokens();
        _initOracles();
        _initParams();
    }

    /// ===================================================================
    /// TOKENS
    /// ===================================================================
    /// @notice Register all stable tokens and collaterals in the system
    /// @dev On testnets we can use the _addMockCollateral to make it deploy mock
    /// collateral tokens.
    function _initTokens() internal {
        _addStableToken("USD", "USDm", "Mento Dollar");
        _addStableToken("EUR", "EURm", "Mento Euro");
        _addStableToken("GBP", "GBPm", "Mento British Pound");

        _addCollateral("USDC", 0x754704Bc059F8C67012fEd69BC8A327a5aafb603);
        _addCollateral("AUSD", 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a);
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal {
        _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes});
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
            threshold: 0.0015 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            aggregator0: 0xf5F15f188AbCB0d165D1Edb7f37F7d6fA2fCebec,
            invert0: false
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
            rateFeed: "AUSD/USD",
            description: "AUSD/USD",
            aggregator0: 0xE20751C7B5867bCBef815ffc1b284c3f412a9e13,
            invert0: false
        });

        _configureDefaultFxRateFeed({
            rateFeed: "GBP/USD",
            source: 0x1ffC8B75a16FFfbd7879F042B580F7607Dcf5C30
        });
        _configureDefaultFxRateFeed({
            rateFeed: "EUR/USD",
            source: 0x00D7E359c8CE46168eFDD4D65b708fFb16c4b99a
        });
    }

    /// ===================================================================
    /// PARAMS
    /// ===================================================================
    /// @notice Configure protocol parameters
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initParams() internal {
        _setDefaultFPMMParams(30, 5, 50, 500, 500);
        _setRedemptionShortfallTolerance(10e12);
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(
        string memory rateFeed,
        address source
    ) internal {
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
        _addChainlinkRelayer({
            rateFeed: rateFeed,
            description: rateFeed,
            aggregator0: source,
            invert0: false
        });
    }
}
