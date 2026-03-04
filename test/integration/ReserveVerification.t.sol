// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";

/// @dev The Reserve contract (Solidity ^0.5.13) has public state variables
///      frozenReserveGoldStartBalance, frozenReserveGoldStartDay, and frozenReserveGoldDays
///      that are not included in the ^0.8 IReserve interface. This local interface
///      matches the actual on-chain auto-generated getter selectors.
interface IReserveFrozenGold {
    function frozenReserveGoldStartBalance() external view returns (uint256);
    function frozenReserveGoldStartDay() external view returns (uint256);
    function frozenReserveGoldDays() external view returns (uint256);
}

/**
 * @title ReserveVerification
 * @notice Verifies that the on-chain Reserve contract configuration matches
 *         the values specified in ReserveConfig:
 *         - tobinTaxStalenessThreshold
 *         - spendingRatio (daily spending ratio for CELO)
 *         - frozenGold / frozenDays
 *         - assetAllocationSymbols[] / assetAllocationWeights[]
 *         - tobinTax / tobinTaxReserveRatio
 *         - collateralAssetDailySpendingRatios[] (per-collateral spending ratios)
 */
contract ReserveVerification is V3IntegrationBase {
    address internal reserve;
    IMentoConfig.ReserveConfig internal reserveConfig;

    function setUp() public override {
        super.setUp();

        reserve = lookupProxyOrFail("Reserve");
        reserveConfig = config.getReserveConfig();
    }

    // ========== Tobin Tax Staleness Threshold ==========

    /// @notice tobinTaxStalenessThreshold must match config
    function test_tobinTaxStalenessThreshold_matchesConfig() public view {
        uint256 actual = IReserve(reserve).tobinTaxStalenessThreshold();
        assertEq(
            actual,
            reserveConfig.tobinTaxStalenessThreshold,
            "Reserve.tobinTaxStalenessThreshold() does not match config"
        );
    }

    // ========== Spending Ratio ==========

    /// @notice Daily spending ratio for CELO must match config
    function test_spendingRatio_matchesConfig() public view {
        uint256 actual = IReserve(reserve).getDailySpendingRatio();
        assertEq(
            actual,
            reserveConfig.spendingRatio,
            "Reserve.getDailySpendingRatio() does not match config"
        );
    }

    // ========== Frozen Gold ==========

    /// @notice frozenReserveGoldStartBalance must match config frozenGold
    function test_frozenGold_matchesConfig() public view {
        uint256 actual = IReserveFrozenGold(reserve).frozenReserveGoldStartBalance();
        assertEq(
            actual,
            reserveConfig.frozenGold,
            "Reserve.frozenReserveGoldStartBalance() does not match config frozenGold"
        );
    }

    /// @notice frozenReserveGoldDays must match config frozenDays
    function test_frozenDays_matchesConfig() public view {
        uint256 actual = IReserveFrozenGold(reserve).frozenReserveGoldDays();
        assertEq(
            actual,
            reserveConfig.frozenDays,
            "Reserve.frozenReserveGoldDays() does not match config frozenDays"
        );
    }

    // ========== Asset Allocation ==========

    /// @notice Asset allocation symbols must match config
    function test_assetAllocationSymbols_matchConfig() public view {
        bytes32[] memory actualSymbols = IReserve(reserve).getAssetAllocationSymbols();
        assertEq(
            actualSymbols.length,
            reserveConfig.assetAllocationSymbols.length,
            "Asset allocation symbols array length mismatch"
        );

        for (uint256 i = 0; i < actualSymbols.length; i++) {
            assertEq(
                actualSymbols[i],
                reserveConfig.assetAllocationSymbols[i],
                string.concat(
                    "Asset allocation symbol mismatch at index ",
                    vm.toString(i)
                )
            );
        }
    }

    /// @notice Asset allocation weights must match config
    function test_assetAllocationWeights_matchConfig() public view {
        uint256[] memory actualWeights = IReserve(reserve).getAssetAllocationWeights();
        assertEq(
            actualWeights.length,
            reserveConfig.assetAllocationWeights.length,
            "Asset allocation weights array length mismatch"
        );

        for (uint256 i = 0; i < actualWeights.length; i++) {
            assertEq(
                actualWeights[i],
                reserveConfig.assetAllocationWeights[i],
                string.concat(
                    "Asset allocation weight mismatch at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== Tobin Tax ==========

    /// @notice tobinTax must match config
    function test_tobinTax_matchesConfig() public view {
        uint256 actual = IReserve(reserve).tobinTax();
        assertEq(
            actual,
            reserveConfig.tobinTax,
            "Reserve.tobinTax() does not match config"
        );
    }

    /// @notice tobinTaxReserveRatio must match config
    function test_tobinTaxReserveRatio_matchesConfig() public view {
        uint256 actual = IReserve(reserve).tobinTaxReserveRatio();
        assertEq(
            actual,
            reserveConfig.tobinTaxReserveRatio,
            "Reserve.tobinTaxReserveRatio() does not match config"
        );
    }

    // ========== Collateral Asset Daily Spending Ratios ==========

    /// @notice Per-collateral daily spending ratios must match config
    function test_collateralAssetDailySpendingRatios_matchConfig() public view {
        address[] memory collateralAssets = config.getCollateralAssets();
        uint256[] memory expectedRatios = reserveConfig.collateralAssetDailySpendingRatios;
        assertEq(
            collateralAssets.length,
            expectedRatios.length,
            "Collateral assets and spending ratios array length mismatch"
        );

        for (uint256 i = 0; i < collateralAssets.length; i++) {
            uint256 actual = IReserve(reserve).getDailySpendingRatioForCollateralAsset(collateralAssets[i]);
            assertEq(
                actual,
                expectedRatios[i],
                string.concat(
                    "Collateral asset daily spending ratio mismatch for asset: ",
                    vm.toString(collateralAssets[i])
                )
            );
        }
    }
}
