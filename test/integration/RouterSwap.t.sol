// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title RouterSwap
 * @notice Tests Router swap flow on all deployed FPMM pools: routing through
 *         correct pool, verifying balances, and pool resolution via FactoryRegistry.
 */
contract RouterSwap is V3IntegrationBase {
    IRouter internal routerContract;
    address[] internal pools;

    function setUp() public override {
        super.setUp();
        routerContract = IRouter(router);
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");
    }

    // ========== Router.swap() routes token0 → token1 through correct pool ==========

    function test_routerSwap_token0ForToken1() public {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM fpmm = IFPMM(pools[i]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(i);
            address trader = makeAddr(string.concat("routerTrader0_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();

            IRouter.Route[] memory routes = new IRouter.Route[](1);
            routes[0] = IRouter.Route({from: t0, to: t1, factory: fpmmFactory});

            uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
            assertEq(expectedAmounts.length, 2, string.concat("Expected 2 amounts for pool ", idx));
            uint256 expectedOut = expectedAmounts[1];
            assertGt(expectedOut, 0, string.concat("getAmountsOut should return non-zero for pool ", idx));

            deal(t0, trader, amountIn);

            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t0).approve(router, amountIn);
            uint256[] memory amounts = routerContract.swapExactTokensForTokens(
                amountIn, expectedOut, routes, trader, block.timestamp + 1 hours
            );
            vm.stopPrank();

            assertEq(amounts[0], amountIn, string.concat("amountIn mismatch for pool ", idx));
            assertEq(amounts[1], expectedOut, string.concat("amountOut mismatch for pool ", idx));

            assertEq(
                IERC20(t0).balanceOf(trader), traderT0Before - amountIn,
                string.concat("token0 balance mismatch for pool ", idx)
            );
            assertEq(
                IERC20(t1).balanceOf(trader), traderT1Before + expectedOut,
                string.concat("token1 balance mismatch for pool ", idx)
            );
        }
    }

    // ========== Router.swap() routes token1 → token0 ==========

    function test_routerSwap_token1ForToken0() public {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM fpmm = IFPMM(pools[i]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(i);
            address trader = makeAddr(string.concat("routerTrader1_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t1).decimals();

            IRouter.Route[] memory routes = new IRouter.Route[](1);
            routes[0] = IRouter.Route({from: t1, to: t0, factory: fpmmFactory});

            uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
            uint256 expectedOut = expectedAmounts[1];
            assertGt(expectedOut, 0, string.concat("getAmountsOut should return non-zero for pool ", idx));

            deal(t1, trader, amountIn);

            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t1).approve(router, amountIn);
            uint256[] memory amounts = routerContract.swapExactTokensForTokens(
                amountIn, expectedOut, routes, trader, block.timestamp + 1 hours
            );
            vm.stopPrank();

            assertEq(amounts[0], amountIn, string.concat("amountIn mismatch for pool ", idx));
            assertEq(amounts[1], expectedOut, string.concat("amountOut mismatch for pool ", idx));

            assertEq(
                IERC20(t1).balanceOf(trader), traderT1Before - amountIn,
                string.concat("token1 balance mismatch for pool ", idx)
            );
            assertEq(
                IERC20(t0).balanceOf(trader), traderT0Before + expectedOut,
                string.concat("token0 balance mismatch for pool ", idx)
            );
        }
    }

    // ========== Router resolves pool via FactoryRegistry ==========

    function test_routerResolvesPoolViaFactoryRegistry() public view {
        assertEq(routerContract.factoryRegistry(), factoryRegistry, "Router.factoryRegistry should match");
        assertEq(routerContract.defaultFactory(), fpmmFactory, "Router.defaultFactory should match FPMMFactory");

        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM fpmm = IFPMM(pools[i]);
            address resolved = routerContract.poolFor(fpmm.token0(), fpmm.token1(), fpmmFactory);
            assertEq(
                resolved, pools[i],
                string.concat("Router.poolFor mismatch for pool at index ", vm.toString(i))
            );
        }
    }
}
