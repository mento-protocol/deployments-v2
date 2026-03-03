// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MentoConfig_celo} from "./MentoConfig_celo.sol";
import {CoreAggregators, FxAggregators, Collaterals} from "./MentoConfig.sol";

contract MentoConfig_celo_sepolia is MentoConfig_celo {

    // ===================================================================
    // Parameters (sepolia overrides)
    // ===================================================================

    function _configureParams() internal override {
        super._configureParams();

        _rateFeedPrefix = "";
        _redemptionShortfallTolerance = 1e12;
        _gbpUsdRateFeedId = getRateFeedIdFromString("GBPUSD");

        // Oracle infrastructure
        _oracleConfig = OracleConfig({
            reportExpirySeconds: 2 days // XXX: testing override
        });
        mockAggregatorReporter = 0xabcdE369CDdD1665E4EbD9214b8e9a595271272C;
        _setMockAggregatorSource("celo");

        // Wrap FX aggregators in mocks (before _coreAggs so we can reference source addresses)
        _fxAggs = FxAggregators({
            eur: _mockAggregator("EUR/USD", _coreAggs.eurcUsd), // No EUR/USD on sepolia, use EURC/USD
            brl: _mockAggregator("BRL/USD", _fxAggs.brl),
            xof: _mockAggregator("XOF/USD", _fxAggs.xof),
            kes: _mockAggregator("KES/USD", _fxAggs.kes),
            php: _mockAggregator("PHP/USD", _fxAggs.php),
            cop: _mockAggregator("COP/USD", _fxAggs.cop),
            ghs: _mockAggregator("GHS/USD", _fxAggs.ghs),
            gbp: _mockAggregator("GBP/USD", _fxAggs.gbp),
            zar: _mockAggregator("ZAR/USD", _fxAggs.zar),
            cad: _mockAggregator("CAD/USD", _fxAggs.cad),
            aud: _mockAggregator("AUD/USD", _fxAggs.aud),
            chf: _mockAggregator("CHF/USD", _fxAggs.chf),
            jpy: _mockAggregator("JPY/USD", _fxAggs.jpy),
            ngn: _mockAggregator("NGN/USD", 0x235e5c8697177931459fA7D19fba7256d29F17DA) // Different source on sepolia
        });

        // Wrap core aggregators in mocks
        _coreAggs = CoreAggregators({
            celoUsd: _mockAggregator("CELO/USD", _coreAggs.celoUsd),
            ethUsd:  _mockAggregator("ETH/USD",  _coreAggs.ethUsd),
            usdcUsd: _mockAggregator("USDC/USD", _coreAggs.usdcUsd),
            usdtUsd: _mockAggregator("USDT/USD", _coreAggs.usdtUsd),
            eurcUsd: _mockAggregator("EURC/USD", _coreAggs.eurcUsd)
        });

        // Collaterals (different addresses on testnet)
        _collaterals = Collaterals({
            usdc:     0x01C5C0122039549AD1493B8220cABEdD739BC44E,
            axlUsdc:  _registerMockCollateral("axlUSDC", 18),
            axlEuroc: _registerMockCollateral("axlEUROC", 18),
            usdt:     0xd077A400968890Eacc75cdc901F0356c943e4fDb,
            celo:     _collaterals.celo
        });
    }

}
