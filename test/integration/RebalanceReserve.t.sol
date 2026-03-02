// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";

/**
 * @title RebalanceReserve
 * @notice Tests ReserveLiquidityStrategy rebalancing on all RLS FPMM pools
 *         in both directions (sell token0 and sell token1), verifying that
 *         different liquidity sources are exercised:
 *         - Large swap to imbalance pool, then rebalance reduces price difference
 *         - Double-rebalance in same tx is blocked (transient storage guard)
 *         - Pool already within threshold cannot be rebalanced
 */
contract RebalanceReserve is V3IntegrationBase {
    ILiquidityStrategy internal strategy;
    address[] internal rlsPools;

    function setUp() public override {
        super.setUp();
        strategy = ILiquidityStrategy(reserveLiquidityStrategy);
        rlsPools = strategy.getPools();
        require(rlsPools.length > 0, "No pools registered with ReserveLiquidityStrategy");
    }

    // ========== Helper: fund reserve with collateral for contraction ==========

    /// @dev Deals collateral to the reserve so contraction rebalances have liquidity
    function _fundReserveWithCollateral(address pool) internal {
        (bool isToken0Debt,,,,,,, ) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);
        address collToken = isToken0Debt ? IFPMM(pool).token1() : IFPMM(pool).token0();
        (uint256 r0, uint256 r1,) = IFPMM(pool).getReserves();
        uint256 amount = (isToken0Debt ? r1 : r0) * 10;
        deal(collToken, reserveV2, amount);
    }

    // ========== Test: rebalance reduces price difference (both directions) ==========

    function test_rebalance_reducesPriceDifference_sellToken0() public {
        _test_rebalance_reducesPriceDifference(true);
    }

    function test_rebalance_reducesPriceDifference_sellToken1() public {
        _test_rebalance_reducesPriceDifference(false);
    }

    function _test_rebalance_reducesPriceDifference(bool sellToken0) internal {
        for (uint256 p = 0; p < rlsPools.length; p++) {
            address pool = rlsPools[p];
            IFPMM fpmm = IFPMM(pool);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("rebalTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);

            _fundReserveWithCollateral(pool);
            _ensureImbalanced(pool, trader, sellToken0);

            (,,,,,, uint256 priceDiffBefore) = fpmm.getRebalancingState();

            vm.warp(block.timestamp + uint256(cooldown) + 1);

            strategy.rebalance(pool);

            (,,,,,, uint256 priceDiffAfter) = fpmm.getRebalancingState();
            assertLt(priceDiffAfter, priceDiffBefore, string.concat("Price diff should decrease for pool ", idx));
        }
    }

    // ========== Test: cannot rebalance same pool twice in one tx ==========

    /// @notice The strategy uses EIP-1153 transient storage to prevent the same pool
    ///         from being rebalanced more than once per transaction.
    function test_rebalance_cannotRebalanceTwiceInSameTx() public {
        for (uint256 p = 0; p < rlsPools.length; p++) {
            address pool = rlsPools[p];
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("cooldownTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);

            _fundReserveWithCollateral(pool);
            _ensureImbalanced(pool, trader, true);

            vm.warp(block.timestamp + uint256(cooldown) + 1);

            strategy.rebalance(pool);

            _ensureImbalanced(pool, trader, true);

            vm.expectRevert(abi.encodeWithSelector(ILiquidityStrategy.LS_CAN_ONLY_REBALANCE_ONCE.selector, pool));
            strategy.rebalance(pool);
        }
    }

    // ========== Test: rebalance reverts when pool is within threshold ==========

    function test_rebalance_revertsWhenWithinThreshold() public {
        for (uint256 p = 0; p < rlsPools.length; p++) {
            address pool = rlsPools[p];
            IFPMM fpmm = IFPMM(pool);

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(reserveLiquidityStrategy).poolConfigs(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);

            (,,,,, uint16 threshold, uint256 priceDiff) = fpmm.getRebalancingState();
            if (priceDiff > uint256(threshold)) {
                strategy.rebalance(pool);
                vm.warp(block.timestamp + uint256(cooldown) + 1);
            }

            vm.expectRevert(ILiquidityStrategy.LS_POOL_NOT_REBALANCEABLE.selector);
            strategy.rebalance(pool);
        }
    }
}
