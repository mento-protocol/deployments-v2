// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title FPMMSwap
 * @notice Tests direct FPMM pool swaps in both directions across all deployed pools,
 *         verifying balances, getAmountOut preview accuracy, and reserve updates.
 */
contract FPMMSwap is V3IntegrationBase {
    address[] internal pools;
    address internal trader;

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");
        trader = makeAddr("trader");
    }

    // ========== Swap token0 → token1 ==========

    function test_swap_token0ForToken1() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);
            assertGt(expectedOut, 0, string.concat("getAmountOut should return non-zero for pool ", idx));

            deal(t0, trader, amountIn);
            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, expectedOut, trader, "");
            vm.stopPrank();

            assertEq(IERC20(t0).balanceOf(trader), traderT0Before - amountIn, string.concat("token0 balance mismatch for pool ", idx));
            assertEq(IERC20(t1).balanceOf(trader), traderT1Before + expectedOut, string.concat("token1 balance mismatch for pool ", idx));
        }
    }

    // ========== Swap token1 → token0 ==========

    function test_swap_token1ForToken0() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);

            uint256 amountIn = 10 ** IERC20Metadata(t1).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t1);
            assertGt(expectedOut, 0, string.concat("getAmountOut should return non-zero for pool ", idx));

            deal(t1, trader, amountIn);
            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t1).transfer(address(fpmm), amountIn);
            fpmm.swap(expectedOut, 0, trader, "");
            vm.stopPrank();

            assertEq(IERC20(t1).balanceOf(trader), traderT1Before - amountIn, string.concat("token1 balance mismatch for pool ", idx));
            assertEq(IERC20(t0).balanceOf(trader), traderT0Before + expectedOut, string.concat("token0 balance mismatch for pool ", idx));
        }
    }

    // ========== getAmountOut preview matches actual output ==========

    function test_getAmountOut_matchesActualSwap() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 previewOut = fpmm.getAmountOut(amountIn, t0);
            assertGt(previewOut, 0, string.concat("Preview should return non-zero for pool ", idx));

            deal(t0, trader, amountIn);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, previewOut, trader, "");
            vm.stopPrank();

            uint256 actualOut = IERC20(t1).balanceOf(trader) - traderT1Before;
            assertEq(actualOut, previewOut, string.concat("Preview mismatch for pool ", idx));
        }
    }

    // ========== Swap updates reserves correctly ==========

    function test_swap_updatesReserves() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            address t0 = fpmm.token0();
            string memory idx = vm.toString(p);

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);

            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();

            deal(t0, trader, amountIn);
            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, expectedOut, trader, "");
            vm.stopPrank();

            uint256 protocolFeeAmount = (amountIn * fpmm.protocolFee()) / 10_000;

            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();

            assertEq(r0After, r0Before + amountIn - protocolFeeAmount, string.concat("reserve0 mismatch for pool ", idx));
            assertEq(r1After, r1Before - expectedOut, string.concat("reserve1 mismatch for pool ", idx));
        }
    }
}
