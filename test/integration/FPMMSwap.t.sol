// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title FPMMSwap
 * @notice Tests direct FPMM pool swaps in both directions, verifying balances,
 *         getAmountOut preview accuracy, and reserve updates.
 */
contract FPMMSwap is V3IntegrationBase {
    address[] internal pools;
    address internal trader;

    // Use the first deployed pool for swap tests
    IFPMM internal fpmm;
    address internal t0;
    address internal t1;

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");

        fpmm = IFPMM(pools[0]);
        t0 = fpmm.token0();
        t1 = fpmm.token1();
        trader = makeAddr("trader");
    }

    // ========== Swap token0 → token1 ==========

    function test_swap_token0ForToken1() public {
        uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();

        // Preview the expected output
        uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);
        assertGt(expectedOut, 0, "getAmountOut should return non-zero");

        // Deal token0 to trader
        deal(t0, trader, amountIn);

        // Record balances before
        uint256 traderT0Before = IERC20(t0).balanceOf(trader);
        uint256 traderT1Before = IERC20(t1).balanceOf(trader);

        // Transfer to pool and swap
        vm.startPrank(trader);
        IERC20(t0).transfer(address(fpmm), amountIn);
        fpmm.swap(0, expectedOut, trader, "");
        vm.stopPrank();

        // Verify balances changed correctly
        uint256 traderT0After = IERC20(t0).balanceOf(trader);
        uint256 traderT1After = IERC20(t1).balanceOf(trader);

        assertEq(traderT0After, traderT0Before - amountIn, "Trader token0 balance should decrease by amountIn");
        assertEq(traderT1After, traderT1Before + expectedOut, "Trader token1 balance should increase by expectedOut");
    }

    // ========== Swap token1 → token0 ==========

    function test_swap_token1ForToken0() public {
        uint256 amountIn = 10 ** IERC20Metadata(t1).decimals();

        // Preview the expected output
        uint256 expectedOut = fpmm.getAmountOut(amountIn, t1);
        assertGt(expectedOut, 0, "getAmountOut should return non-zero");

        // Deal token1 to trader
        deal(t1, trader, amountIn);

        // Record balances before
        uint256 traderT0Before = IERC20(t0).balanceOf(trader);
        uint256 traderT1Before = IERC20(t1).balanceOf(trader);

        // Transfer to pool and swap
        vm.startPrank(trader);
        IERC20(t1).transfer(address(fpmm), amountIn);
        fpmm.swap(expectedOut, 0, trader, "");
        vm.stopPrank();

        // Verify balances changed correctly
        uint256 traderT0After = IERC20(t0).balanceOf(trader);
        uint256 traderT1After = IERC20(t1).balanceOf(trader);

        assertEq(traderT1After, traderT1Before - amountIn, "Trader token1 balance should decrease by amountIn");
        assertEq(traderT0After, traderT0Before + expectedOut, "Trader token0 balance should increase by expectedOut");
    }

    // ========== getAmountOut preview matches actual output ==========

    function test_getAmountOut_matchesActualSwap() public {
        uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();

        // Preview
        uint256 previewOut = fpmm.getAmountOut(amountIn, t0);
        assertGt(previewOut, 0, "Preview should return non-zero");

        // Deal and swap
        deal(t0, trader, amountIn);
        uint256 traderT1Before = IERC20(t1).balanceOf(trader);

        vm.startPrank(trader);
        IERC20(t0).transfer(address(fpmm), amountIn);
        fpmm.swap(0, previewOut, trader, "");
        vm.stopPrank();

        uint256 actualOut = IERC20(t1).balanceOf(trader) - traderT1Before;
        assertEq(actualOut, previewOut, "Actual swap output should match getAmountOut preview");
    }

    // ========== Swap updates reserves correctly ==========

    function test_swap_updatesReserves() public {
        uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
        uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);

        // Record reserves before
        (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();

        // Deal and swap token0 → token1
        deal(t0, trader, amountIn);
        vm.startPrank(trader);
        IERC20(t0).transfer(address(fpmm), amountIn);
        fpmm.swap(0, expectedOut, trader, "");
        vm.stopPrank();

        // Record reserves after
        (uint256 r0After, uint256 r1After,) = fpmm.getReserves();

        // reserve0 should increase by amountIn, reserve1 should decrease by expectedOut
        assertEq(r0After, r0Before + amountIn, "reserve0 should increase by amountIn");
        assertEq(r1After, r1Before - expectedOut, "reserve1 should decrease by expectedOut");
    }
}
