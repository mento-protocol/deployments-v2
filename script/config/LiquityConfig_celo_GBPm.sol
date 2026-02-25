// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquityConfig} from "./ILiquityConfig.sol";

/**
 * @notice Liquity GBPm/USDm instance config for Celo.
 */
contract LiquityConfig_celo_GBPm is ILiquityConfig {
    function get()
        external
        pure
        override
        returns (ILiquityConfig.LiquityInstanceConfig memory)
    {
        return
            ILiquityConfig.LiquityInstanceConfig({
                instanceSalt: "v3.0.0-liquity-GBPm",
                // ── Registry lookup keys ────────────────────────────────
                // TODO: change to labels used in prestage Celo script
                debtTokenLabel: "StableTokenV3:GBPm",
                collateralTokenLabel: "StableTokenV3:USDm",
                liquidityStrategyLabel: "CDPLiquidityStrategy",
                gasTokenLabel: "StableTokenV3:USDm",
                oracleAdapterLabel: "OracleAdapter",
                // ── Addresses ──────────────────────────────────────────
                rateFeedID: 0xf590b62f9cfcc6409075b1ecAc8176fe25744B88, // GBP/USD
                watchdog: 0x287810F677516f10993ff63a520aAD5509F35796, // TODO: change to FXPriceFeed Watchdog Celo
                owner: 0x287810F677516f10993ff63a520aAD5509F35796, // TODO: change to Owner Celo
                yieldSplitAddress: 0x287810F677516f10993ff63a520aAD5509F35796, // TODO: change to Yield Split Address Celo
                // ── FXPriceFeed ────────────────────────────────────────
                invertRateFeed: true, // SortedOracles: GBP/USD is inverted as (USD/GBP)
                l2SequencerGracePeriod: 1200, // 20 minutes
                // ── Collateral params ──────────────────────────────────
                CCR: 1e18 * 1.35, // 135%
                MCR: 1e18 * 1.1, // 110%
                BCR: 1e18 * 0.1, // 10%
                SCR: 1e18 * 1.1, // 110%
                liquidationPenaltySP: 1e18 * 0.05, // 5%
                liquidationPenaltyRedistribution: 1e18 * 0.1, // 10%
                // ── SystemParams: debt ─────────────────────────────────
                minDebt: 1_000e18, // 1,000 GBPm
                // ── SystemParams: gas compensation ─────────────────────
                collGasCompensationDivisor: 200,
                collGasCompensationCap: 10e18, // 10 USDm
                ethGasCompensation: 1e18, // 1 CELO
                // ── SystemParams: interest ─────────────────────────────
                minAnnualInterestRate: 1e18 * 0.002, // 0.2%
                // ── SystemParams: redemption ───────────────────────────
                redemptionFeeFloor: 1e18 * 0.005, // 0.5%
                initialBaseRate: 1e18, // 100%
                redemptionMinuteDecayFactor: 1e18 * 9885140204, // 60 minutes half-life time
                redemptionBeta: 1,
                // ── SystemParams: stability pool ───────────────────────
                spYieldSplit: 1e18 * 0.75, // 75%
                minBoldInSP: 1e18, // 1 GBPm
                minBoldAfterRebalance: 5_000e18, // 5_000 GBPm
                // ── NFT Metadata assets ───────────────────────────────
                metadataAssetsBasePath: "script/assets/anvil-GBPm/", // TODO: change to celo
                debtTokenLogoFile: "gbpm_logo.txt", // TODO: change to celo
                collateralTokenLogoFile: "usdm_logo.txt", // TODO: change to celo
                collateralTokenSymbol: "USDm",
                fontFile: "geist.txt" // TODO: change to celo
            });
    }
}