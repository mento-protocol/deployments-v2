// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMentoConfig} from "../interfaces/IMentoConfig.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

abstract contract MentoConfig is IMentoConfig {
    // ========== Storage ==========

    TokenConfig[] internal _tokens;
    RateFeedConfig[] internal _rateFeeds;
    CollateralAsset[] internal _collateralAssets;
    address[] internal _oracleAddresses;

    OracleConfig internal _oracleConfig;
    BreakerBoxConfig internal _breakerBoxConfig;
    ReserveConfig internal _reserveConfig;
    TradingLimitsConfig internal _tradingLimitsConfig;
    PoolDefaultConfig internal _poolDefaultConfig;

    mapping(address rateFeedId => ChainlinkRelayerConfig)
        internal _chainlinkRelayers;
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

    function getRateFeedConfigs()
        external
        view
        returns (RateFeedConfig[] memory)
    {
        return _rateFeeds;
    }

    function getCollateralAssets()
        external
        view
        returns (CollateralAsset[] memory)
    {
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

    function getTradingLimitsConfig()
        external
        view
        returns (TradingLimitsConfig memory)
    {
        return _tradingLimitsConfig;
    }

    function getPoolDefaultConfig()
        external
        view
        returns (PoolDefaultConfig memory)
    {
        return _poolDefaultConfig;
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

    // ========== Helper Functions ==========

    function getRateFeedId(
        string memory asset0,
        string memory asset1
    ) public pure returns (address) {
        string memory pair = string(abi.encodePacked(asset0, "/", asset1));
        return address(uint160(uint256(keccak256(abi.encodePacked(pair)))));
    }

    function getRateFeedIdFromString(
        string memory feedId
    ) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(feedId)))));
    }

    // ========== Internal Helper Functions ==========

    function _addToken(string memory symbol, string memory name) internal {
        _tokens.push(TokenConfig({symbol: symbol, name: name}));
    }

    function _addRateFeed(
        string memory id,
        string memory asset0,
        string memory asset1
    ) internal {
        _rateFeeds.push(
            RateFeedConfig({id: id, asset0: asset0, asset1: asset1})
        );
    }

    function _addCollateralAsset(address addr) internal {
        _collateralAssets.push(CollateralAsset({addr: addr}));
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
}

