// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {MentoConfig_base} from "./MentoConfig_base.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_base_sepolia is MentoConfig_base {
    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal override {
        _registerMockCollateral("EURC", 6);
        _addReserveV2Collateral("EURC");
    }

    // ===================================================================
    // Parameters (testnet overrides)
    // ===================================================================
    function _configureParams() internal override {
        super._configureParams();

        // Oracle infrastructure
        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("base");

        // Wrap core aggregators in mocks
        _coreAggs = CoreAggregators({
            usdcUsd: address(0),
            usdtUsd: address(0),
            eurcUsd: _mockAggregator("EURC/USD", "EURC/USD", _coreAggs.eurcUsd),
            ausdUsd: address(0),
            celoUsd: address(0),
            ethUsd: address(0)
        });

        // Wrap FX aggregators in mocks
        _fxAggs = FxAggregators({
            eur: _mockAggregator("EUR/USD", "EUR/USD", _fxAggs.eur),
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
    /// ORACLES
    /// ===================================================================
    /// @dev Override the parent's expiries to 1 week on testnet. Must run
    /// after super._initOracles() so the parent's tighter mainnet values
    /// don't overwrite ours.
    function _initOracles() internal override {
        super._initOracles();
        _oracleConfig = OracleConfig({reportExpirySeconds: 1 weeks});
        _setRateFeedExpirySeconds("EURC/EUR", 1 weeks);
    }
}
