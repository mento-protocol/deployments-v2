// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
import {MentoConfig_polygon} from "./MentoConfig_polygon.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {bytes32s, uints, bytesList} from "lib/mento-std/src/Array.sol";

import {IFPMM} from "lib/mento-core/contracts/interfaces/IFPMM.sol";

contract MentoConfig_polygon_testnet is MentoConfig_polygon {
    /// ===================================================================
    /// COLLATERAL
    /// ===================================================================
    function _initCollateral() internal override {
        // _addCollateral("USDC", lookup("USDC")); // do we need this?
        _registerMockCollateral("USDC", 6);
        _registerMockCollateral("USDT0", 6);

        _addReserveV2Collateral("USDC");
        _addReserveV2Collateral("USDT0");
    }

    // ===================================================================
    // Parameters (testnet overrides)
    // ===================================================================
    function _configureParams() internal override {
        super._configureParams();

        // Oracle infrastructure
        // _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes}); // do we need this?
        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("polygon");

        // Wrap core aggregators in mocks
        _coreAggs = CoreAggregators({
            usdcUsd: _mockAggregator("USDC/USD", "USDC/USD", _coreAggs.usdcUsd),
            usdtUsd: _mockAggregator("USDT/USD", "USDT/USD", _coreAggs.usdtUsd)
        });

        // Wrap FX aggregators in mocks
        _fxAggs = FxAggregators({
            eur: _mockAggregator("EUR/USD", "EUR/USD", _fxAggs.eur)
        });
    }
}
