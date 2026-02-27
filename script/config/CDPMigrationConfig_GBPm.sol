// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICDPMigrationConfig} from "./ICDPMigrationConfig.sol";

contract CDPMigrationConfig_GBPm is ICDPMigrationConfig {
    function get() external pure returns (CDPMigrationInstanceConfig memory) {
        return CDPMigrationInstanceConfig({
            // ── ReserveTroveFactory ──────────────────────────────────────────
            reserveTroveManagerAddress: address(0), // TODO: address that will own the trove NFT ReserveMultisig?
            collateralizationRatio: 1.7e18, // TODO: 170% — adjust as needed
            interestRate: 0.002e18, // TODO: 0.2% annual current min — adjust as needed
            // ── CDPConfig ────────────────────────────────────────────────────
            stabilityPoolPercentage: 2000, // 20% in bps
            maxIterations: 500,
            // ── AddPoolParams ────────────────────────────────────────────────
            cooldown: 5 minutes, // rebalance cooldown
            protocolFeeRecipient: address(0), // TODO: config says treasury address
            liquiditySourceIncentiveExpansion: 0.005e18, // 0.5%
            protocolIncentiveExpansion: 0, // 0%
            liquiditySourceIncentiveContraction: 0.005e18, // 0.5%
            protocolIncentiveContraction: 0, // 0%
            // ── FXPriceFeed ──────────────────────────────────────────────────
            rateFeedID: 0xf590b62f9cfcc6409075b1ecAc8176fe25744B88 // rate feed ID for GBP/USD
        });
    }
}
