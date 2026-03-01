// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal interface to read the auto-generated poolConfigs getter from LiquidityStrategy
interface IPoolConfigReader {
    function poolConfigs(address pool) external view returns (
        bool isToken0Debt,
        uint32 lastRebalance,
        uint32 rebalanceCooldown,
        address protocolFeeRecipient,
        uint64 liquiditySourceIncentiveExpansion,
        uint64 protocolIncentiveExpansion,
        uint64 liquiditySourceIncentiveContraction,
        uint64 protocolIncentiveContraction
    );
}

/**
 * @title RebalanceCDP
 * @notice Tests CDPLiquidityStrategy rebalancing on CDP-backed FPMM pools:
 *         - Large swap to imbalance pool, then rebalance reduces price difference
 *         - Cooldown is respected (calling again immediately reverts)
 *         - Pool already within threshold cannot be rebalanced
 */
contract RebalanceCDP is V3IntegrationBase {
    ILiquidityStrategy internal strategy;
    address internal pool;
    IFPMM internal fpmm;
    address internal t0;
    address internal t1;
    address internal trader;
    uint32 internal cooldown;

    function setUp() public override {
        super.setUp();
        strategy = ILiquidityStrategy(cdpLiquidityStrategy);

        // Get pools registered with CDPLiquidityStrategy
        address[] memory pools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
        require(pools.length > 0, "No pools registered with CDPLiquidityStrategy");

        pool = pools[0];
        fpmm = IFPMM(pool);
        t0 = fpmm.token0();
        t1 = fpmm.token1();
        trader = makeAddr("cdpRebalanceTrader");

        // Read cooldown from pool config
        (,, uint32 _cooldown,,,,,) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);
        cooldown = _cooldown;
    }

    // ========== Helper: do a large one-sided swap to imbalance the pool ==========

    function _imbalancePool() internal {
        // Get current reserves to determine a large enough swap amount
        (uint256 r0, uint256 r1,) = fpmm.getReserves();

        // Swap 10% of reserve0 worth of token0 → token1 to push price
        uint256 amountIn = r0 / 10;
        require(amountIn > 0, "Reserve0 too low for imbalance swap");

        uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);
        require(expectedOut > 0, "getAmountOut returned zero for imbalance swap");
        require(expectedOut < r1, "expectedOut exceeds reserve1");

        deal(t0, trader, amountIn);
        vm.startPrank(trader);
        IERC20(t0).transfer(address(fpmm), amountIn);
        fpmm.swap(0, expectedOut, trader, "");
        vm.stopPrank();
    }

    // ========== Test: rebalance reduces price difference ==========

    function test_rebalance_reducesPriceDifference() public {
        // Imbalance the pool with a large swap
        _imbalancePool();

        // Record rebalancing state before
        (,,,,,, uint256 priceDiffBefore) = fpmm.getRebalancingState();

        // If not already rebalanceable, do additional swaps
        (,,,,, uint16 threshold,) = fpmm.getRebalancingState();
        if (priceDiffBefore <= uint256(threshold)) {
            _imbalancePool();
            (,,,,,, priceDiffBefore) = fpmm.getRebalancingState();
        }

        // Skip past any existing cooldown
        vm.warp(block.timestamp + uint256(cooldown) + 1);

        // Execute rebalance
        strategy.rebalance(pool);

        // Record rebalancing state after
        (,,,,,, uint256 priceDiffAfter) = fpmm.getRebalancingState();

        // Price difference should have decreased
        assertLt(priceDiffAfter, priceDiffBefore, "Price difference should decrease after rebalance");
    }

    // ========== Test: cooldown is respected ==========

    function test_rebalance_respectsCooldown() public {
        // Imbalance the pool
        _imbalancePool();

        // Skip past any existing cooldown
        vm.warp(block.timestamp + uint256(cooldown) + 1);

        // Check if pool is rebalanceable
        (,,,,, uint16 threshold, uint256 priceDiff) = fpmm.getRebalancingState();
        if (priceDiff <= uint256(threshold)) {
            _imbalancePool();
        }

        // First rebalance should succeed
        strategy.rebalance(pool);

        // If cooldown is 0, this test is not applicable — skip
        if (cooldown == 0) {
            return;
        }

        // Imbalance again so pool needs rebalancing
        _imbalancePool();
        (,,,,, threshold, priceDiff) = fpmm.getRebalancingState();
        if (priceDiff <= uint256(threshold)) {
            _imbalancePool();
        }

        // Calling rebalance again immediately should revert with LS_COOLDOWN_ACTIVE
        vm.expectRevert(ILiquidityStrategy.LS_COOLDOWN_ACTIVE.selector);
        strategy.rebalance(pool);
    }

    // ========== Test: rebalance reverts when pool is within threshold ==========

    function test_rebalance_revertsWhenWithinThreshold() public {
        // Skip past any existing cooldown
        vm.warp(block.timestamp + uint256(cooldown) + 1);

        // Check current rebalancing state — the pool may already be within threshold
        (,,,,, uint16 threshold, uint256 priceDiff) = fpmm.getRebalancingState();

        if (priceDiff > uint256(threshold)) {
            // Pool is out of balance — rebalance it first to bring within threshold
            strategy.rebalance(pool);
            // Advance past cooldown
            vm.warp(block.timestamp + uint256(cooldown) + 1);
        }

        // Now pool should be within threshold — rebalance should revert
        vm.expectRevert(ILiquidityStrategy.LS_POOL_NOT_REBALANCEABLE.selector);
        strategy.rebalance(pool);
    }
}
