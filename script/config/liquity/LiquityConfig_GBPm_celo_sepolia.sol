// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquityConfig} from "../ILiquityConfig.sol";

/**
 * @notice Liquity GBPm/USDm instance config for Celo.
 */
contract LiquityConfig_GBPm_celo_sepolia is ILiquityConfig {
    function get() external pure override returns (ILiquityConfig.LiquityInstanceConfig memory) {
        return ILiquityConfig.LiquityInstanceConfig({
            proxyLabel: "GBPm",
            singletonLabel: "v3.0.0-GBPm",
            // ── Registry lookup keys ────────────────────────────────
            debtTokenLabel: "GBPm",
            collateralTokenLabel: "USDm",
            // ── Addresses ──────────────────────────────────────────
            rateFeedID: 0xAe5eEe6815b8529847955d19522858806Bca8217, // GBP/USD
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
            redemptionMinuteDecayFactor: 1e18 * 0.9885140204, // 60 minutes half-life time
            redemptionBeta: 1,
            // ── SystemParams: stability pool ───────────────────────
            spYieldSplit: 1e18 * 0.75, // 75%
            minBoldInSP: 1e18, // 1 GBPm
            minBoldAfterRebalance: 5_000e18, // 5_000 GBPm
            // ── NFT Metadata assets ───────────────────────────────
            metadataAssetsBasePath: "script/config/liquity/assets/",
            debtTokenLogoFile: "GBPm.svg",
            collateralTokenLogoFile: "USDm.svg",
            collateralTokenSymbol: "USDm",
            fontFile: "geist.txt"
        });
    }
}
