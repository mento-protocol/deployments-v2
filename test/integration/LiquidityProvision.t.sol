// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title LiquidityProvision
 * @notice Tests FPMM liquidity provision (mint) and removal (burn), verifying
 *         LP tokens, reserves, and proportional share behavior.
 */
contract LiquidityProvision is V3IntegrationBase {
    address[] internal pools;
    address internal lp;

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
        lp = makeAddr("lp");
    }

    // ========== Provide liquidity ==========

    function test_mint_provideLiquidity() public {
        // Get current reserves to calculate proportional amounts
        (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
        assertGt(r0Before, 0, "Pool should have non-zero reserve0");
        assertGt(r1Before, 0, "Pool should have non-zero reserve1");

        uint256 totalSupplyBefore = IERC20(address(fpmm)).totalSupply();
        assertGt(totalSupplyBefore, 0, "Pool should have non-zero totalSupply");

        // Add ~1% of existing reserves proportionally
        uint256 amount0 = r0Before / 100;
        uint256 amount1 = r1Before / 100;

        // Deal tokens to LP
        deal(t0, lp, amount0);
        deal(t1, lp, amount1);

        // Transfer tokens to pool and mint LP tokens
        vm.startPrank(lp);
        IERC20(t0).transfer(address(fpmm), amount0);
        IERC20(t1).transfer(address(fpmm), amount1);
        uint256 liquidity = fpmm.mint(lp);
        vm.stopPrank();

        // Verify LP tokens received
        assertGt(liquidity, 0, "Should receive non-zero LP tokens");
        assertEq(IERC20(address(fpmm)).balanceOf(lp), liquidity, "LP balance should match minted amount");

        // Verify reserves increased
        (uint256 r0After, uint256 r1After,) = fpmm.getReserves();
        assertEq(r0After, r0Before + amount0, "reserve0 should increase by amount0");
        assertEq(r1After, r1Before + amount1, "reserve1 should increase by amount1");

        // Verify total supply increased
        uint256 totalSupplyAfter = IERC20(address(fpmm)).totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore + liquidity, "totalSupply should increase by liquidity minted");
    }

    // ========== Remove liquidity ==========

    function test_burn_removeLiquidity() public {
        // First, add liquidity so we have LP tokens to burn
        (uint256 r0Initial, uint256 r1Initial,) = fpmm.getReserves();
        uint256 amount0 = r0Initial / 100;
        uint256 amount1 = r1Initial / 100;

        deal(t0, lp, amount0);
        deal(t1, lp, amount1);

        vm.startPrank(lp);
        IERC20(t0).transfer(address(fpmm), amount0);
        IERC20(t1).transfer(address(fpmm), amount1);
        uint256 liquidity = fpmm.mint(lp);
        vm.stopPrank();

        assertGt(liquidity, 0, "Should have LP tokens to burn");

        // Record state before burn
        (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
        uint256 totalSupplyBefore = IERC20(address(fpmm)).totalSupply();
        uint256 lpT0Before = IERC20(t0).balanceOf(lp);
        uint256 lpT1Before = IERC20(t1).balanceOf(lp);

        // Transfer LP tokens to pool and burn
        vm.startPrank(lp);
        IERC20(address(fpmm)).transfer(address(fpmm), liquidity);
        (uint256 out0, uint256 out1) = fpmm.burn(lp);
        vm.stopPrank();

        // Verify tokens returned
        assertGt(out0, 0, "Should receive non-zero token0");
        assertGt(out1, 0, "Should receive non-zero token1");
        assertEq(IERC20(t0).balanceOf(lp), lpT0Before + out0, "LP token0 balance should increase");
        assertEq(IERC20(t1).balanceOf(lp), lpT1Before + out1, "LP token1 balance should increase");

        // Verify LP tokens burned
        assertEq(IERC20(address(fpmm)).balanceOf(lp), 0, "LP should have no remaining LP tokens");

        // Verify reserves decreased proportionally
        (uint256 r0After, uint256 r1After,) = fpmm.getReserves();
        assertEq(r0After, r0Before - out0, "reserve0 should decrease by out0");
        assertEq(r1After, r1Before - out1, "reserve1 should decrease by out1");

        // Verify total supply decreased
        uint256 totalSupplyAfter = IERC20(address(fpmm)).totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore - liquidity, "totalSupply should decrease by burned liquidity");
    }

    // ========== LP token balance reflects proportional share ==========

    function test_lpTokenBalance_reflectsProportionalShare() public {
        // Get initial state
        (uint256 r0Initial, uint256 r1Initial,) = fpmm.getReserves();

        // Add ~1% of reserves proportionally
        uint256 amount0 = r0Initial / 100;
        uint256 amount1 = r1Initial / 100;

        deal(t0, lp, amount0);
        deal(t1, lp, amount1);

        vm.startPrank(lp);
        IERC20(t0).transfer(address(fpmm), amount0);
        IERC20(t1).transfer(address(fpmm), amount1);
        uint256 liquidity = fpmm.mint(lp);
        vm.stopPrank();

        // LP's share of pool should be approximately proportional to deposit
        uint256 totalSupplyAfter = IERC20(address(fpmm)).totalSupply();
        (uint256 r0After, uint256 r1After,) = fpmm.getReserves();

        // LP's proportional claim on reserves should match deposit amounts (within rounding)
        uint256 expectedClaim0 = (r0After * liquidity) / totalSupplyAfter;
        uint256 expectedClaim1 = (r1After * liquidity) / totalSupplyAfter;

        // Allow 1 wei tolerance for rounding
        assertApproxEqAbs(expectedClaim0, amount0, 1, "LP's proportional claim on token0 should match deposit");
        assertApproxEqAbs(expectedClaim1, amount1, 1, "LP's proportional claim on token1 should match deposit");

        // LP's share percentage should be approximately 1% (since we added 1% of reserves)
        // liquidity / totalSupplyAfter ≈ amount0 / r0After ≈ 1/101
        uint256 shareNumerator = liquidity * 10000;
        uint256 sharePct = shareNumerator / totalSupplyAfter; // basis points
        // Expected: ~99 bps (1/101 ≈ 0.99%)
        assertGt(sharePct, 90, "LP share should be > 0.90%");
        assertLt(sharePct, 110, "LP share should be < 1.10%");
    }
}
