// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBiPoolManager, IPricingModule, FixidityLib} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

interface IMentoConfig {
    // ========== Structs ==========

    struct TokenConfig {
        string symbol;
        string name;
    }

    struct ChainlinkRelayerConfig {
        string rateFeed; // e.g., "USDfx/CELO"
        address rateFeedId; // keccak(rateFeed)
        string rateFeedDescription;
        uint256 maxTimestampSpread;
        IChainlinkRelayer.ChainlinkAggregator[] aggregators;
    }

    struct ExchangeConfig {
        IBiPoolManager.PoolExchange pool;
        ExchangeTrandingLimitsConfig tradingLimits;
    }

    struct ExchangeTrandingLimitsConfig {
        ITradingLimits.Config asset0;
        ITradingLimits.Config asset1;
    }

    struct ReserveConfig {
        uint256 tobinTaxStalenessThreshold;
        uint256 spendingRatio;
        uint256 frozenGold;
        uint256 frozenDays;
        bytes32[] assetAllocationSymbols;
        uint256[] assetAllocationWeights;
        uint256 tobinTax;
        uint256 tobinTaxReserveRatio;
        uint256[] collateralAssetDailySpendingRatios;
    }

    struct BreakerBoxConfig {
        uint256 defaultCooldownTime;
    }

    struct OracleConfig {
        uint256 reportExpirySeconds;
    }

    // ========== Arrays ==========

    function getTokenConfigs() external view returns (TokenConfig[] memory);

    function getRateFeedIds() external view returns (address[] memory);

    function getCollateralAssets() external view returns (address[] memory);

    function getChainlinkRelayerConfigs()
        external
        view
        returns (ChainlinkRelayerConfig[] memory);

    function getExchanges() external view returns (ExchangeConfig[] memory);

    // ========== Config Structs ==========

    function getOracleConfig() external view returns (OracleConfig memory);

    function getBreakerBoxConfig()
        external
        view
        returns (BreakerBoxConfig memory);

    function getReserveConfig() external view returns (ReserveConfig memory);

    // ========== Helpers ==========

    function getRateFeedIdFromString(
        string memory feedId
    ) external pure returns (address);
}
