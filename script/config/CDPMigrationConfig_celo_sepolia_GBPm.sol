// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICDPMigrationConfig} from "./ICDPMigrationConfig.sol";

contract CDPMigrationConfig_celo_sepolia_GBPm is ICDPMigrationConfig {
    function get() external pure returns (CDPMigrationInstanceConfig memory) {
        return CDPMigrationInstanceConfig({
            // ── ReserveTroveFactory ──────────────────────────────────────────
            collateralizationRatio: 1.7e18, // TODO: 170% — adjust as needed
            interestRate: 0.002e18, // TODO: 0.2% annual current min — adjust as needed
            // ── CDPConfig ────────────────────────────────────────────────────
            stabilityPoolPercentage: 2000, // 20% in bps
            maxIterations: 500,
            // ── AddPoolParams ────────────────────────────────────────────────
            cooldown: 5 minutes, // rebalance cooldown
            liquiditySourceIncentiveExpansion: 0.0005e18, // 0.05%
            protocolIncentiveExpansion: 0, // 0%
            liquiditySourceIncentiveContraction: 0.0005e18, // 0.05%
            protocolIncentiveContraction: 0, // 0%
            // ── FXPriceFeed ──────────────────────────────────────────────────
            // celo sepolia rate feed id for GBP/USD: address(uint160(uint256(keccak256("GBPUSD"))))
            rateFeedID: 0xAe5eEe6815b8529847955d19522858806Bca8217
        });
    }
}
