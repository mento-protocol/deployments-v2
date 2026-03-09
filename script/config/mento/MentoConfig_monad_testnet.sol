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
    function _initCollateral() internal override {
        _addCollateral("USDC", lookup("USDC"));
        _registerMockCollateral("AUSD", 6);

        _addReserveV2Collateral("USDC");
        _addReserveV2Collateral("AUSD");
    }

    /// ===================================================================
    /// ORACLES
    /// ===================================================================
    /// @notice Configure oracle ratefeeds and circuit breaker
    /// @dev On testnets we can use _addMockAggregator to define chainlink
    /// aggregators.
    function _initOracles() internal override {
        _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes});
        valueBreakerId = _addBreaker({breakerType: BreakerType.Value, defaultCooldownTime: 0, defaultThreshold: 0});
        medianBreakerId = _addBreaker({breakerType: BreakerType.Median, defaultCooldownTime: 0, defaultThreshold: 0});

        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("monad");

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
            label: "USDC/USD", description: "USDC/USD", source: 0xf5F15f188AbCB0d165D1Edb7f37F7d6fA2fCebec
        });
        _addChainlinkRelayer({
            rateFeed: "USDC/USD",
            description: "USDC/USD",
            aggregator0: _predict("MockChainlinkAggregator", "USDC/USD"),
            invert0: false
        });

        _addRateFeed("AUSD/USD");
        _addToBreaker({
            breakerId: valueBreakerId,
            rateFeed: "AUSD/USD",
            cooldown: 1,
            threshold: 0.001 * 1e24,
            smoothingFactor: 0,
            referenceValue: 1 * 1e24
        });
        _addMockAggregator({
            label: "AUSD/USD", description: "AUSD/USD", source: 0xE20751C7B5867bCBef815ffc1b284c3f412a9e13
        });
        _addChainlinkRelayer({
            rateFeed: "AUSD/USD",
            description: "AUSD/USD",
            aggregator0: _predict("MockChainlinkAggregator", "AUSD/USD"),
            invert0: false
        });

        _configureDefaultFxRateFeed({currency: "GBP", source: 0x1ffC8B75a16FFfbd7879F042B580F7607Dcf5C30});
    }

    /// @notice Helper function to configure an FX rate feed, they have
    /// the same breaker configuration.
    function _configureDefaultFxRateFeed(string memory currency, address source) internal override {
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
}
