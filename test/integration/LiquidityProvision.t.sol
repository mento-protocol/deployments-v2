// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title LiquidityProvision
 * @notice Tests FPMM liquidity provision (mint) and removal (burn) on all
 *         deployed pools, verifying LP tokens, reserves, and proportional
 *         share behavior.
 */
contract LiquidityProvision is V3IntegrationBase {
    address[] internal pools;

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");
        for (uint256 i = 0; i < pools.length; i++) {
            _ensurePoolLiquidity(pools[i]);
        }
    }

    // ========== Provide liquidity ==========

    function test_mint_provideLiquidity() public {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM fpmm = IFPMM(pools[i]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(i);
            address lp = makeAddr(string.concat("lpMint_", idx));

            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
            assertGt(r0Before, 0, string.concat("reserve0 zero for pool ", idx));
            assertGt(r1Before, 0, string.concat("reserve1 zero for pool ", idx));

            uint256 totalSupplyBefore = IERC20(pools[i]).totalSupply();
            assertGt(totalSupplyBefore, 0, string.concat("totalSupply zero for pool ", idx));

            uint256 amount0 = r0Before / 100;
            uint256 amount1 = r1Before / 100;

            _dealTokens(t0, lp, amount0);
            _dealTokens(t1, lp, amount1);

            vm.startPrank(lp);
            IERC20(t0).transfer(pools[i], amount0);
            IERC20(t1).transfer(pools[i], amount1);
            uint256 liquidity = fpmm.mint(lp);
            vm.stopPrank();

            assertGt(liquidity, 0, string.concat("LP tokens zero for pool ", idx));
            assertEq(IERC20(pools[i]).balanceOf(lp), liquidity, string.concat("LP balance mismatch for pool ", idx));

            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();
            assertEq(r0After, r0Before + amount0, string.concat("reserve0 mismatch for pool ", idx));
            assertEq(r1After, r1Before + amount1, string.concat("reserve1 mismatch for pool ", idx));

            uint256 totalSupplyAfter = IERC20(pools[i]).totalSupply();
            assertEq(
                totalSupplyAfter, totalSupplyBefore + liquidity, string.concat("totalSupply mismatch for pool ", idx)
            );
        }
    }

    // ========== Remove liquidity ==========

    function test_burn_removeLiquidity() public {
        for (uint256 i = 0; i < pools.length; i++) {
            _test_burn_singlePool(pools[i], vm.toString(i));
        }
    }

    /// @dev Adds 1% liquidity to a pool, returns (lp, liquidity)
    function _addLiquidity(address pool, string memory idx) internal returns (address lp, uint256 liquidity) {
        IFPMM fpmm = IFPMM(pool);
        address t0 = fpmm.token0();
        address t1 = fpmm.token1();
        lp = makeAddr(string.concat("lpBurn_", idx));

        (uint256 r0, uint256 r1,) = fpmm.getReserves();
        uint256 amount0 = r0 / 100;
        uint256 amount1 = r1 / 100;

        _dealTokens(t0, lp, amount0);
        _dealTokens(t1, lp, amount1);

        vm.startPrank(lp);
        IERC20(t0).transfer(pool, amount0);
        IERC20(t1).transfer(pool, amount1);
        liquidity = fpmm.mint(lp);
        vm.stopPrank();

        assertGt(liquidity, 0, string.concat("No LP tokens to burn for pool ", idx));
    }

    function _test_burn_singlePool(address pool, string memory idx) internal {
        (address lp, uint256 liquidity) = _addLiquidity(pool, idx);

        // Record state before burn
        (uint256 r0Before, uint256 r1Before,) = IFPMM(pool).getReserves();
        uint256 totalSupplyBefore = IERC20(pool).totalSupply();
        uint256 lpT0Before = IERC20(IFPMM(pool).token0()).balanceOf(lp);
        uint256 lpT1Before = IERC20(IFPMM(pool).token1()).balanceOf(lp);

        // Burn LP tokens
        vm.startPrank(lp);
        IERC20(pool).transfer(pool, liquidity);
        (uint256 out0, uint256 out1) = IFPMM(pool).burn(lp);
        vm.stopPrank();

        assertGt(out0, 0, string.concat("out0 zero for pool ", idx));
        assertGt(out1, 0, string.concat("out1 zero for pool ", idx));
        assertEq(
            IERC20(IFPMM(pool).token0()).balanceOf(lp),
            lpT0Before + out0,
            string.concat("token0 mismatch for pool ", idx)
        );
        assertEq(
            IERC20(IFPMM(pool).token1()).balanceOf(lp),
            lpT1Before + out1,
            string.concat("token1 mismatch for pool ", idx)
        );
        assertEq(IERC20(pool).balanceOf(lp), 0, string.concat("LP still has tokens for pool ", idx));

        (uint256 r0After, uint256 r1After,) = IFPMM(pool).getReserves();
        assertEq(r0After, r0Before - out0, string.concat("reserve0 mismatch for pool ", idx));
        assertEq(r1After, r1Before - out1, string.concat("reserve1 mismatch for pool ", idx));

        assertEq(
            IERC20(pool).totalSupply(),
            totalSupplyBefore - liquidity,
            string.concat("totalSupply mismatch for pool ", idx)
        );
    }

    // ========== LP token balance reflects proportional share ==========

    function test_lpTokenBalance_reflectsProportionalShare() public {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM fpmm = IFPMM(pools[i]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(i);
            address lp = makeAddr(string.concat("lpShare_", idx));

            (uint256 r0Initial, uint256 r1Initial,) = fpmm.getReserves();

            uint256 amount0 = r0Initial / 100;
            uint256 amount1 = r1Initial / 100;

            _dealTokens(t0, lp, amount0);
            _dealTokens(t1, lp, amount1);

            vm.startPrank(lp);
            IERC20(t0).transfer(pools[i], amount0);
            IERC20(t1).transfer(pools[i], amount1);
            uint256 liquidity = fpmm.mint(lp);
            vm.stopPrank();

            uint256 totalSupplyAfter = IERC20(pools[i]).totalSupply();
            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();

            uint256 expectedClaim0 = (r0After * liquidity) / totalSupplyAfter;
            uint256 expectedClaim1 = (r1After * liquidity) / totalSupplyAfter;

            // Use 0.01% relative tolerance to handle rounding across different decimal tokens
            assertApproxEqRel(
                expectedClaim0, amount0, 2e14, string.concat("Proportional claim0 mismatch for pool ", idx)
            );
            assertApproxEqRel(
                expectedClaim1, amount1, 2e14, string.concat("Proportional claim1 mismatch for pool ", idx)
            );
        }
    }
}
