// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

import {IMentoConfig, IBiPoolManager, ITradingLimits, IPricingModule, FixidityLib} from "../interfaces/IMentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

abstract contract MentoConfig is TrebScript, ProxyHelper, IMentoConfig {
    // ========== Storage ==========

    TokenConfig[] internal _tokens;
    address[] internal _rateFeedIds;
    address[] internal _collateralAssets;
    ExchangeConfig[] internal _exchanges;
    address[] internal _oracleAddresses;

    OracleConfig internal _oracleConfig;
    BreakerBoxConfig internal _breakerBoxConfig;
    ReserveConfig internal _reserveConfig;

    mapping(address rateFeedId => ChainlinkRelayerConfig)
        internal _chainlinkRelayers;

    mapping(string symbol => address) _collateral;
    address[] _chainlinkRelayerRateFeedIds;

    // ========== Constructor ==========

    constructor() {
        _initialize();
    }

    // ========== Abstract Functions ==========

    function _initialize() internal virtual;

    // ========== View Functions ==========

    function getTokenConfigs() external view returns (TokenConfig[] memory) {
        return _tokens;
    }

    function getCollateralAssets() external view returns (address[] memory) {
        return _collateralAssets;
    }

    function getOracleAddresses() external view returns (address[] memory) {
        return _oracleAddresses;
    }

    function getOracleConfig() external view returns (OracleConfig memory) {
        return _oracleConfig;
    }

    function getBreakerBoxConfig()
        external
        view
        returns (BreakerBoxConfig memory)
    {
        return _breakerBoxConfig;
    }

    function getReserveConfig() external view returns (ReserveConfig memory) {
        return _reserveConfig;
    }

    function getChainlinkRelayerConfigs()
        external
        view
        returns (ChainlinkRelayerConfig[] memory relayerConfigs)
    {
        relayerConfigs = new ChainlinkRelayerConfig[](
            _chainlinkRelayerRateFeedIds.length
        );
        for (uint i = 0; i < _chainlinkRelayerRateFeedIds.length; i++) {
            address rateFeedId = _chainlinkRelayerRateFeedIds[i];
            relayerConfigs[i] = abi.decode(
                abi.encode(_chainlinkRelayers[rateFeedId]),
                (ChainlinkRelayerConfig)
            );
        }
    }

    function getExchanges()
        external
        view
        returns (ExchangeConfig[] memory exchanges)
    {
        return _exchanges;
    }

    function getRateFeedIds() external view returns (address[] memory) {
        return _rateFeedIds;
    }

    // ========== Helper Functions ==========

    function emptyTradingLimits()
        internal
        pure
        returns (ITradingLimits.Config memory)
    {}

    function getRateFeedIdFromString(
        string memory feedId
    ) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(feedId)))));
    }

    // ========== Internal Helper Functions ==========

    function _addStableToken(
        string memory symbol,
        string memory name
    ) internal {
        _tokens.push(TokenConfig({symbol: symbol, name: name}));
    }

    function _addCollateral(string memory symbol, address addy) internal {
        _collateralAssets.push(addy);
        _collateral[symbol] = addy;
    }

    function _addRateFeed(string memory rateFeed) internal {
        _rateFeedIds.push(getRateFeedIdFromString(rateFeed));
    }

    function _addOracleAddress(address oracle) internal {
        _oracleAddresses.push(oracle);
    }

    function _createChainlinkAggregator(
        address aggregator,
        bool invert
    ) internal pure returns (IChainlinkRelayer.ChainlinkAggregator memory) {
        return
            IChainlinkRelayer.ChainlinkAggregator({
                aggregator: aggregator,
                invert: invert
            });
    }

    function _addChainlinkRelayer(
        string memory rateFeed,
        string memory description,
        uint256 maxTimestampSpread,
        address aggregator0,
        bool invert0
    ) internal {
        IChainlinkRelayer.ChainlinkAggregator[]
            memory aggregators = new IChainlinkRelayer.ChainlinkAggregator[](1);
        aggregators[0] = IChainlinkRelayer.ChainlinkAggregator({
            aggregator: aggregator0,
            invert: invert0
        });

        _addChainlinkRelayer(
            rateFeed,
            description,
            maxTimestampSpread,
            aggregators
        );
    }

    function _addChainlinkRelayer(
        string memory rateFeed,
        string memory description,
        uint256 maxTimestampSpread,
        IChainlinkRelayer.ChainlinkAggregator[] memory aggregators
    ) internal {
        address rateFeedId = getRateFeedIdFromString(rateFeed);
        _chainlinkRelayerRateFeedIds.push(rateFeedId);
        _chainlinkRelayers[rateFeedId].rateFeedId = rateFeedId;
        _chainlinkRelayers[rateFeedId].rateFeed = rateFeed;
        _chainlinkRelayers[rateFeedId].rateFeedDescription = description;
        _chainlinkRelayers[rateFeedId].maxTimestampSpread = maxTimestampSpread;
        for (uint i = 0; i < aggregators.length; i++) {
            _chainlinkRelayers[rateFeedId].aggregators.push(aggregators[i]);
        }
    }

    function _addExchange(
        string memory asset0,
        string memory asset1,
        string memory pricingModule,
        uint256 spread,
        string memory rateFeed,
        uint256 resetFrequency,
        uint256 stablePoolResetSize,
        ExchangeTrandingLimitsConfig memory tradingLimits
    ) internal {
        address _asset0 = _resolveExchangeAsset(asset0);
        address _asset1 = _resolveExchangeAsset(asset1);
        address _pricingModule = lookup(pricingModule);
        if (
            _asset0 == address(0) ||
            _asset1 == address(0) ||
            _pricingModule == address(0)
        ) {
            console.log(
                string.concat(
                    "[WARN] Skipping pool ",
                    asset0,
                    asset1,
                    ": Could not resolve assets or pricing module"
                )
            );
            return;
        }
        _exchanges.push(
            ExchangeConfig({
                pool: IBiPoolManager.PoolExchange({
                    asset0: _asset0,
                    asset1: _asset1,
                    pricingModule: IPricingModule(_pricingModule),
                    bucket0: 0,
                    bucket1: 0,
                    lastBucketUpdate: 0,
                    config: IBiPoolManager.PoolConfig({
                        spread: FixidityLib.wrap(spread),
                        referenceRateFeedID: getRateFeedIdFromString(rateFeed),
                        referenceRateResetFrequency: resetFrequency,
                        minimumReports: 1,
                        stablePoolResetSize: stablePoolResetSize
                    })
                }),
                tradingLimits: tradingLimits
            })
        );
    }

    function _resolveExchangeAsset(
        string memory symbol
    ) internal view returns (address) {
        if (_collateral[symbol] != address(0)) {
            return _collateral[symbol];
        } else {
            return lookupProxy(symbol);
        }
    }
}
