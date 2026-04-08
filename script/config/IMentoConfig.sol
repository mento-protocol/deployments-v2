// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBiPoolManager, IPricingModule, FixidityLib} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";

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
        string label;
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
        ExchangeTradingLimitsConfig tradingLimits;
        bool createVirtual;
    }

    struct ExchangeTradingLimitsConfig {
        ITradingLimits.Config asset0;
        ITradingLimits.Config asset1;
    }

    struct RateFeed {
        string rateFeed;
        address rateFeedId;
    }

    struct LockingConfig {
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

    struct LiquidityStrategyPoolConfig {
        address liquidityStrategy;
        address debtToken;
        uint32 cooldown;
        address protocolFeeRecipient;
        uint64 liquiditySourceIncentiveExpansion;
        uint64 protocolIncentiveExpansion;
        uint64 liquiditySourceIncentiveContraction;
        uint64 protocolIncentiveContraction;
    }

    struct TokenLimits {
        uint256 limit0;
        uint256 limit1;
    }

    struct FPMMTradingLimitsConfig {
        uint256 token0Limit0;
        uint256 token0Limit1;
        uint256 token1Limit0;
        uint256 token1Limit1;
    }

    struct FPMMConfig {
        address fpmmImplementation;
        address oracleAdapter;
        address proxyAdmin;
        address token0;
        address token1;
        address referenceRateFeedID;
        bool invertRateFeed;
        IFPMM.FPMMParams params;
        FPMMTradingLimitsConfig tradingLimits;
        LiquidityStrategyPoolConfig liquidityStrategyConfig;
    }

    struct CDPMigrationConfig {
        // ── ReserveTroveFactory ──────────────────────────────────────────
        uint256 collateralizationRatio; // 18 decimals, e.g. 1.5e18 = 150%
        uint256 interestRate; // 18 decimals, annual
        // ── CDPConfig ────────────────────────────────────────────────────
        uint16 stabilityPoolPercentage; // bps
        uint16 maxIterations;
        // ── AddPoolParams ────────────────────────────────────────────────
        uint32 cooldown; // rebalance cooldown in seconds
        uint64 liquiditySourceIncentiveExpansion;
        uint64 protocolIncentiveExpansion;
        uint64 liquiditySourceIncentiveContraction;
        uint64 protocolIncentiveContraction;
        // ── FXPriceFeed ──────────────────────────────────────────────────
        address rateFeedID;
    }

    function getCDPMigrationConfig(string calldata token) external view returns (CDPMigrationConfig memory);

    function getTokenConfigs() external view returns (TokenConfig[] memory);

    function getRateFeedIds() external view returns (address[] memory);

    function getFxRateFeedIds() external view returns (address[] memory);

    function getRateFeeds() external view returns (RateFeed[] memory);

    function getRateFeedExpirySeconds(string calldata rateFeed) external view returns (uint256);

    function getRateFeedDependencies(address) external view returns (address[] memory);

    function getCollateralAssets() external view returns (address[] memory);

    function getReserveV2CollateralAssets() external view returns (address[] memory);

    function getChainlinkRelayerConfigs() external view returns (ChainlinkRelayerConfig[] memory);

    function getExchanges() external view returns (ExchangeConfig[] memory);

    function getMockAggregatorConfigs() external returns (MockAggregatorConfig[] memory);

    function getOracleConfig() external view returns (OracleConfig memory);

    function getLockingConfig() external view returns (LockingConfig memory);

    function getGovernanceConfig() external view returns (GovernanceConfig memory);

    function getBreakerConfigs() external view returns (BreakerConfig[] memory configs);

    function getReserveConfig() external view returns (ReserveConfig memory);

    function getFPMMConfigs() external view returns (FPMMConfig[] memory);

    function getDefaultFPMMParams() external view returns (IFPMM.FPMMParams memory);

    function getFPMMParams(address token0, address token1) external view returns (IFPMM.FPMMParams memory);

    function getCDPRedemptionShortfallTolerance() external view returns (uint256);

    function mockAggregatorReporter() external view returns (address);

    function mockAggregatorSourceFork() external view returns (uint256);

    function baseFork() external view returns (uint256);

    function getMockCollaterals() external view returns (string[] memory);

    function isCollateralAsset(address token) external view returns (bool);

    // ========== Helpers ==========

    function getRateFeedIdFromString(string memory feedId) external pure returns (address);

    function getExchangeId(address asset0, address asset1, address pricingModule) external view returns (bytes32);

    function getExchangeId(address asset0, address asset1) external view returns (bytes32);

    function getExchangeConfig(address asset0, address asset1, address pricingModule)
        external
        view
        returns (ExchangeConfig memory config, bool found);

    function getAddress(string memory asset) external returns (address);

    function getTokenDecimals(string memory symbol) external view returns (uint8);
}
