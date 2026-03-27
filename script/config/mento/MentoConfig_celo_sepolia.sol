// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

        // Oracle infrastructure
        _oracleConfig = OracleConfig({reportExpirySeconds: 5 minutes});
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
}
