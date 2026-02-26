// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICDPMigrationConfig} from "./ICDPMigrationConfig.sol";

contract CDPMigrationConfig_GBPm is ICDPMigrationConfig {
    function get() external pure returns (CDPMigrationInstanceConfig memory) {
        return CDPMigrationInstanceConfig({
            // ── Registry lookup keys ─────────────────────────────────────────
            addressesRegistryLabel: "", // TODO: e.g. "AddressesRegistry_GBPm"
            fpmmLabel: "", // TODO: e.g. "FPMM_GBPm_USDC"
            reserveLiquidityStrategyLabel: "", // TODO: e.g. "ReserveLiquidityStrategy"
            cdpLiquidityStrategyLabel: "", // TODO: e.g. "CDPLiquidityStrategy"
            // ── ReserveTroveFactory ──────────────────────────────────────────
            reserveTroveManagerAddress: address(0), // TODO: address that will own the trove NFT ReserveMultisig?
            collateralizationRatio: 1.7e18, // TODO: 170% — adjust as needed
            interestRate: 0.002e18, // TODO: 0.2% annual current min — adjust as needed
            // ── CDPConfig ────────────────────────────────────────────────────
            stabilityPoolPercentage: 2000, // TODO: 20% in bps — adjust as needed
            maxIterations: 500, // TODO: adjust as needed
            // ── AddPoolParams ────────────────────────────────────────────────
            cooldown: 5 minutes, // TODO: rebalance cooldown — adjust as needed
            protocolFeeRecipient: address(0), // TODO: config says treasury address
            liquiditySourceIncentiveExpansion: 0.005e18, // TODO: 0.5% — adjust as needed
            protocolIncentiveExpansion: 0, // TODO: adjust as needed
            liquiditySourceIncentiveContraction: 0.005e18, // TODO: 0.5% — adjust as needed
            protocolIncentiveContraction: 0, // TODO: adjust as needed
            // ── FXPriceFeed ──────────────────────────────────────────────────
            rateFeedID: 0xf590b62f9cfcc6409075b1ecAc8176fe25744B88 // rate feed ID for GBP/USD
        });
    }
}
