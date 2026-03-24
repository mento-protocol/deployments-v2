// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {ITradingLimits, BreakerType, CoreAggregators, FxAggregators} from "./MentoConfig.sol";
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
        _registerMockCollateral("USDT0", 6);


        _addReserveV2Collateral("USDC");
        _addReserveV2Collateral("AUSD");
        _addReserveV2Collateral("USDT0");
    }

    // ===================================================================
    // Parameters (testnet overrides)
    // ===================================================================
    function _configureParams() internal override {
        super._configureParams();

        // Oracle infrastructure
        _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes});
        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("monad");

        // Wrap core aggregators in mocks
        _coreAggs = CoreAggregators({
            celoUsd: address(0),
            ethUsd: address(0),
            usdcUsd: _mockAggregator("USDC/USD", "USDC/USD", _coreAggs.usdcUsd),
            usdtUsd: _mockAggregator("USDT/USD", "USDT/USD", _coreAggs.usdtUsd),
            eurcUsd: address(0),
            ausdUsd: _mockAggregator("AUSD/USD", "AUSD/USD", _coreAggs.ausdUsd)
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
            gbp: _mockAggregator("GBP/USD", "GBP/USD", _fxAggs.gbp),
            zar: address(0),
            cad: address(0),
            aud: address(0),
            chf: address(0),
            jpy: address(0),
            ngn: address(0)
        });
    }
}
