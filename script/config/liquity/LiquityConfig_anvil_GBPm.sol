// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILiquityConfig} from "../ILiquityConfig.sol";

/**
 * @notice Liquity GBPm/USDm instance config for Anvil (local Monad mainnet fork).
 * @dev gasTokenLabel == collateralTokenLabel: USDm serves as both collateral and gas token.
 */
contract LiquityConfig_anvil_GBPm is ILiquityConfig {
    function get()
        external
        pure
        override
        returns (ILiquityConfig.LiquityInstanceConfig memory)
    {
        return
            ILiquityConfig.LiquityInstanceConfig({
                proxyLabel: "GBPm",
                singletonLabel: "v3.0.0-GBPm",
                // ── Registry lookup keys ────────────────────────────────
                debtTokenLabel: "StableTokenV3:GBPm",
                collateralTokenLabel: "StableTokenV3:USDm",
                liquidityStrategyLabel: "CDPLiquidityStrategy",
                gasTokenLabel: "StableTokenV3:USDm",
                oracleAdapterLabel: "OracleAdapter",
                // ── Addresses ──────────────────────────────────────────
                rateFeedID: 0x00000000000000000000000000000000075BCd15,
                watchdog: 0x00000000000000000000000000000002DfDC1c3E,
                owner: 0x000000000000000000000000000000000001E240,
                yieldSplitAddress: 0x000000000000000000000000000000000001e241,
                // ── FXPriceFeed ────────────────────────────────────────
                invertRateFeed: false,
                l2SequencerGracePeriod: 1200,
                // ── Collateral params ──────────────────────────────────
                CCR: 1500000000000000000,
                MCR: 1100000000000000000,
                BCR: 100000000000000000,
                SCR: 1100000000000000000,
                liquidationPenaltySP: 50000000000000000,
                liquidationPenaltyRedistribution: 100000000000000000,
                // ── SystemParams: debt ─────────────────────────────────
                minDebt: 100000000000000000000,
                // ── SystemParams: gas compensation ─────────────────────
                collGasCompensationDivisor: 200,
                collGasCompensationCap: 2000000000000000000,
                ethGasCompensation: 37500000000000000,
                // ── SystemParams: interest ─────────────────────────────
                minAnnualInterestRate: 5000000000000000,
                // ── SystemParams: redemption ───────────────────────────
                redemptionFeeFloor: 2500000000000000,
                initialBaseRate: 1000000000000000000,
                redemptionMinuteDecayFactor: 998076443575628800,
                redemptionBeta: 1,
                // ── SystemParams: stability pool ───────────────────────
                spYieldSplit: 750000000000000000,
                minBoldInSP: 1000000000000000000,
                minBoldAfterRebalance: 1000000000000000000000,
                // ── NFT Metadata assets ───────────────────────────────
                metadataAssetsBasePath: "script/config/liquity/assets/",
                debtTokenLogoFile: "GBPm.svg",
                collateralTokenLogoFile: "USDm.svg",
                collateralTokenSymbol: "USDm",
                fontFile: "geist.txt"
            });
    }
}
