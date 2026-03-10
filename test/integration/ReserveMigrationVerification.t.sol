// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {console} from "forge-std/console.sol";

/**
 * @title ReserveMigrationVerification
 * @notice Verifies ReserveLiquidityStrategy deployment state per pool:
 *         - RLS is registered as liquidity strategy on each FPMM
 *         - Pool config has valid non-zero values
 *         - Debt tokens are registered as stable assets on ReserveV2
 *         - Collateral tokens are registered as collateral assets on ReserveV2
 *         - RLS has minter/burner rights on each pool's debt token
 *         - RLS.reserve() points to ReserveV2
 */
contract ReserveMigrationVerification is V3IntegrationBase {
    address[] internal rlsPools;

    function setUp() public override {
        super.setUp();
        rlsPools = ILiquidityStrategy(reserveLiquidityStrategy).getPools();
    }

    // ========== RLS Pools Exist ==========

    function test_rlsPools_exist() public view {
        assertGt(rlsPools.length, 0, "No pools registered with ReserveLiquidityStrategy");
    }

    // ========== RLS Registered as LiquidityStrategy on FPMM ==========

    function test_rlsPools_strategyEnabledOnFPMM() public view {
        for (uint256 i = 0; i < rlsPools.length; i++) {
            assertTrue(
                IFPMM(rlsPools[i]).liquidityStrategy(reserveLiquidityStrategy),
                string.concat("ReserveLiquidityStrategy not enabled on FPMM pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Pool Config Valid ==========

    function test_rlsPools_poolConfig_valid() public view {
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < rlsPools.length; i++) {
            (
                ,,
                uint32 rebalanceCooldown,
                address protocolFeeRecipient,
                uint64 lsIncentiveExpansion,
                uint64 protocolIncentiveExpansion,
                uint64 lsIncentiveContraction,
                uint64 protocolIncentiveContraction
            ) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(rlsPools[i]);

            IMentoConfig.LiquidityStrategyPoolConfig memory expected = _findRlsConfig(fpmmConfigs, rlsPools[i]);

            string memory idx = vm.toString(i);

            assertEq(
                rebalanceCooldown, expected.cooldown, string.concat("Pool config cooldown mismatch at index ", idx)
            );
            assertEq(
                protocolFeeRecipient,
                expected.protocolFeeRecipient,
                string.concat("Pool config protocolFeeRecipient mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveExpansion,
                expected.liquiditySourceIncentiveExpansion,
                string.concat("Pool config lsIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveExpansion,
                expected.protocolIncentiveExpansion,
                string.concat("Pool config protocolIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveContraction,
                expected.liquiditySourceIncentiveContraction,
                string.concat("Pool config lsIncentiveContraction mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveContraction,
                expected.protocolIncentiveContraction,
                string.concat("Pool config protocolIncentiveContraction mismatch at index ", idx)
            );
        }
    }

    /// @dev Finds the RLS pool config for a pool by matching its token pair in FPMMConfigs
    function _findRlsConfig(IMentoConfig.FPMMConfig[] memory fpmmConfigs, address pool)
        internal
        view
        returns (IMentoConfig.LiquidityStrategyPoolConfig memory)
    {
        address t0 = IFPMM(pool).token0();
        address t1 = IFPMM(pool).token1();
        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            if (
                (fpmmConfigs[i].token0 == t0 && fpmmConfigs[i].token1 == t1)
                    || (fpmmConfigs[i].token0 == t1 && fpmmConfigs[i].token1 == t0)
            ) {
                return fpmmConfigs[i].liquidityStrategyConfig;
            }
        }
        revert("RLS config not found for token pair");
    }

    // ========== ReserveV2 Asset Registration ==========

    /// @notice Verify each RLS pool's debt token is registered as a stable asset on ReserveV2
    function test_rlsPools_debtToken_isStableAsset() public view {
        for (uint256 i = 0; i < rlsPools.length; i++) {
            address debtToken = _getRlsDebtToken(rlsPools[i]);
            assertTrue(
                IReserveV2(reserveV2).isStableAsset(debtToken),
                string.concat(
                    "Debt token not registered as stable asset on ReserveV2 for pool at index ", vm.toString(i)
                )
            );
        }
    }

    /// @notice Verify each RLS pool's collateral token is registered as a collateral asset on ReserveV2
    function test_rlsPools_collateralToken_isCollateralAsset() public view {
        for (uint256 i = 0; i < rlsPools.length; i++) {
            address collateralToken = _getRlsCollateralToken(rlsPools[i]);
            assertTrue(
                IReserveV2(reserveV2).isCollateralAsset(collateralToken),
                string.concat(
                    "Collateral token not registered as collateral asset on ReserveV2 for pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== RLS Minter/Burner on Debt Tokens ==========

    /// @notice Verify RLS has minter role on each pool's debt token
    function test_rlsPools_rls_isMinter() public view {
        for (uint256 i = 0; i < rlsPools.length; i++) {
            address debtToken = _getRlsDebtToken(rlsPools[i]);
            assertTrue(
                IStableTokenV3(debtToken).isMinter(reserveLiquidityStrategy),
                string.concat("ReserveLiquidityStrategy not minter on debt token for pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify RLS has burner role on each pool's debt token
    function test_rlsPools_rls_isBurner() public view {
        for (uint256 i = 0; i < rlsPools.length; i++) {
            address debtToken = _getRlsDebtToken(rlsPools[i]);
            assertTrue(
                IStableTokenV3(debtToken).isBurner(reserveLiquidityStrategy),
                string.concat("ReserveLiquidityStrategy not burner on debt token for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== RLS.reserve() Points to ReserveV2 ==========

    function test_rls_reserve_pointsToReserveV2() public view {
        address actual = address(IReserveLiquidityStrategy(reserveLiquidityStrategy).reserve());
        assertEq(actual, reserveV2, "ReserveLiquidityStrategy.reserve() should point to ReserveV2");
    }

    // ========== Internal Helpers ==========

    /// @dev Returns the debt token for an RLS pool based on the isToken0Debt flag
    function _getRlsDebtToken(address pool) internal view returns (address) {
        (bool isToken0Debt,,,,,,,) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);
        return isToken0Debt ? IFPMM(pool).token0() : IFPMM(pool).token1();
    }

    /// @dev Returns the collateral token for an RLS pool (the non-debt token)
    function _getRlsCollateralToken(address pool) internal view returns (address) {
        (bool isToken0Debt,,,,,,,) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);
        return isToken0Debt ? IFPMM(pool).token1() : IFPMM(pool).token0();
    }
}
