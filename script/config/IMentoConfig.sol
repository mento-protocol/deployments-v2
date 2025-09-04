// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBiPoolManager, IPricingModule, FixidityLib} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";

enum BreakerType {
    Value,
    Median
}

interface IMentoConfig {
    // ========== Structs ==========

    struct TokenConfig {
        string symbol;
        string name;
        string currency;
    }

    struct MockAggregatorConfig {
        string description;
        uint8 decimals;
        int256 initialReport;
        address source;
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

    struct LockingConfig {
        uint256 startingPointWeek;
        uint256 minCliffPeriod;
        uint256 minSlopePeriod;
    }

    struct GovernanceConfig {
        uint256 timelockDelay;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorum;
        address watchdog;
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

    struct BreakerConfig {
        BreakerType breakerType;
        uint256 defaultCooldownTime;
        uint256 defaultThreshold;
        address[] rateFeedIds;
        uint256[] cooldownTimes;
        uint256[] thresholds;
        uint256[] smoothingFactors;
        uint256[] referenceValues;
    }

    struct OracleConfig {
        uint256 reportExpirySeconds;
    }

    function getTokenConfigs() external view returns (TokenConfig[] memory);

    function getRateFeedIds() external view returns (address[] memory);

    function getCollateralAssets() external view returns (address[] memory);

    function getChainlinkRelayerConfigs()
        external
        view
        returns (ChainlinkRelayerConfig[] memory);

    function getExchanges() external view returns (ExchangeConfig[] memory);

    function getMockAggregatorConfigs()
        external
        view
        returns (MockAggregatorConfig[] memory);

    function getOracleConfig() external view returns (OracleConfig memory);

    function getLockingConfig() external view returns (LockingConfig memory);

    function getGovernanceConfig()
        external
        view
        returns (GovernanceConfig memory);

    function getBreakerConfigs()
        external
        view
        returns (BreakerConfig[] memory configs);

    function getReserveConfig() external view returns (ReserveConfig memory);

    function mockAggregatorReporter() external view returns (address);

    function mockAggregatorSourceFork() external view returns (uint256);

    function baseFork() external view returns (uint256);

    function getMockCollaterals() external view returns (string[] memory);

    // ========== Helpers ==========

    function getRateFeedIdFromString(
        string memory feedId
    ) external pure returns (address);

    function getExchangeId(
        address asset0,
        address asset1,
        address pricingModule
    ) external view returns (bytes32);

    function getExchangeId(
        address asset0,
        address asset1
    ) external view returns (bytes32);

    function getAddress(string memory asset) external view returns (address);
}
