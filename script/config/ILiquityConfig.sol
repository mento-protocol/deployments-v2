// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquityConfig {
    struct LiquityInstanceConfig {
        // ── Instance identity ────────────────────────────────────────────
        /// @dev Unique salt used for all instance-specific CREATE3 deployments
        ///      (BorrowerOperations, TroveManager, StabilityPool proxy, etc.)
        ///      e.g. "v3.0.0-liquity-GBPm-USDm"
        string instanceSalt;
        // ── Registry lookup keys ─────────────────────────────────────────
        string debtTokenLabel; // e.g. "StableTokenV3:GBPm"
        string collateralTokenLabel; // e.g. "StableTokenV3:USDm"
        string liquidityStrategyLabel; // e.g. "CDPLiquidityStrategy"
        string gasTokenLabel; // e.g. "StableTokenV3:USDm"
        string oracleAdapterLabel; // e.g. "OracleAdapter"
        // ── Addresses ────────────────────────────────────────────────────
        address rateFeedID;
        address watchdog;
        address owner;
        address yieldSplitAddress;
        // ── FXPriceFeed ──────────────────────────────────────────────────
        bool invertRateFeed;
        uint256 l2SequencerGracePeriod;
        // ── Collateral / TroveManager params ─────────────────────────────
        uint256 CCR;
        uint256 MCR;
        uint256 BCR;
        uint256 SCR;
        uint256 liquidationPenaltySP;
        uint256 liquidationPenaltyRedistribution;
        // ── SystemParams: debt ───────────────────────────────────────────
        uint256 minDebt;
        // ── SystemParams: gas compensation ───────────────────────────────
        uint256 collGasCompensationDivisor;
        uint256 collGasCompensationCap;
        uint256 ethGasCompensation;
        // ── SystemParams: interest ───────────────────────────────────────
        uint256 minAnnualInterestRate;
        // ── SystemParams: redemption ─────────────────────────────────────
        uint256 redemptionFeeFloor;
        uint256 initialBaseRate;
        uint256 redemptionMinuteDecayFactor;
        uint256 redemptionBeta;
        // ── SystemParams: stability pool ─────────────────────────────────
        uint256 spYieldSplit;
        uint256 minBoldInSP;
        uint256 minBoldAfterRebalance;
        // ── NFT Metadata assets ─────────────────────────────────────────
        /// @dev Base directory for asset files, relative to project root
        ///      e.g. "lib/bold/contracts/utils/assets/"
        string metadataAssetsBasePath;
        /// @dev Filename for the debt token logo (stored under "BOLD" key)
        string debtTokenLogoFile;
        /// @dev Filename for the collateral token logo
        string collateralTokenLogoFile;
        /// @dev Must match IERC20Metadata(collateralToken).symbol()
        string collateralTokenSymbol;
        /// @dev Filename for the font file (stored under "geist" key)
        string fontFile;
    }

    function get() external view returns (LiquityInstanceConfig memory);
}
