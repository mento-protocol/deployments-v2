// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

interface IMentoConfig {
    // ========== Structs ==========

    struct TokenConfig {
        string symbol;
        string name;
    }

    struct RateFeedConfig {
        string id; // e.g., "USDfx/CELO"
        string asset0;
        string asset1;
    }

    struct CollateralAsset {
        address addr;
    }

    struct ChainlinkRelayerConfig {
        string rateFeed; // e.g., "USDfx/CELO"
        address rateFeedId; // keccak(rateFeed)
        string rateFeedDescription;
        uint256 maxTimestampSpread;
        IChainlinkRelayer.ChainlinkAggregator[] aggregators;
    }

    struct PoolDefaultConfig {
        uint256 defaultSpread;
        uint256 defaultBucketSize;
        uint256 minimumReports;
        uint256 referenceRateResetFrequency;
        uint256 stablePoolResetSize;
        string pricingModule;
    }

    struct TradingLimitsConfig {
        uint32 timestep0;
        uint32 timestep1;
        int48 limit0;
        int48 limit1;
        int48 limitGlobal;
        uint8 flags;
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

    function getRateFeedConfigs()
        external
        view
        returns (RateFeedConfig[] memory);

    function getCollateralAssets()
        external
        view
        returns (CollateralAsset[] memory);

    function getOracleAddresses() external view returns (address[] memory);

    function getChainlinkRelayerConfigs()
        external
        view
        returns (ChainlinkRelayerConfig[] memory);

    // ========== Config Structs ==========

    function getOracleConfig() external view returns (OracleConfig memory);

    function getBreakerBoxConfig()
        external
        view
        returns (BreakerBoxConfig memory);

    function getReserveConfig() external view returns (ReserveConfig memory);

    function getTradingLimitsConfig()
        external
        view
        returns (TradingLimitsConfig memory);

    function getPoolDefaultConfig()
        external
        view
        returns (PoolDefaultConfig memory);

    // ========== Helpers ==========

    function getRateFeedId(
        string memory asset0,
        string memory asset1
    ) external pure returns (address);

    function getRateFeedIdFromString(
        string memory feedId
    ) external pure returns (address);
}

