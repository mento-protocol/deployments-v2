// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICDPMigrationConfig {
    struct CDPMigrationInstanceConfig {
        // ── Registry lookup keys ─────────────────────────────────────────
        string addressesRegistryLabel;
        string fpmmLabel;
        // ── ReserveTroveFactory ──────────────────────────────────────────
        address reserveTroveManagerAddress;
        uint256 collateralizationRatio; // 18 decimals, e.g. 1.5e18 = 150%
        uint256 interestRate; // 18 decimals, annual
        // ── CDPConfig ────────────────────────────────────────────────────
        uint16 stabilityPoolPercentage; // bps
        uint16 maxIterations;
        // ── AddPoolParams ────────────────────────────────────────────────
        uint32 cooldown; // rebalance cooldown in seconds
        address protocolFeeRecipient;
        uint64 liquiditySourceIncentiveExpansion;
        uint64 protocolIncentiveExpansion;
        uint64 liquiditySourceIncentiveContraction;
        uint64 protocolIncentiveContraction;
        // ── FXPriceFeed ──────────────────────────────────────────────────
        address rateFeedID;
    }

    function get() external view returns (CDPMigrationInstanceConfig memory);
}
