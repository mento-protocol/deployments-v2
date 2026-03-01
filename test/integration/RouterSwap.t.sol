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
 * @notice Tests Router swap flow: routing through correct FPMM pool,
 *         verifying balances, and pool resolution via FactoryRegistry.
 */
contract RouterSwap is V3IntegrationBase {
    IRouter internal routerContract;
    address[] internal pools;
    address internal trader;

    IFPMM internal fpmm;
    address internal t0;
    address internal t1;

    function setUp() public override {
        super.setUp();
        routerContract = IRouter(router);
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");

        fpmm = IFPMM(pools[0]);
        t0 = fpmm.token0();
        t1 = fpmm.token1();
        trader = makeAddr("routerTrader");
    }

    // ========== Router.swap() routes token0 → token1 through correct pool ==========

    function test_routerSwap_token0ForToken1() public {
        uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();

        // Build the route: token0 → token1 via the default factory (FPMMFactory)
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: t0, to: t1, factory: fpmmFactory});

        // Preview expected output via Router
        uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
        // expectedAmounts[0] = amountIn, expectedAmounts[1] = amountOut
        assertEq(expectedAmounts.length, 2, "Expected 2 amounts from single-hop route");
        uint256 expectedOut = expectedAmounts[1];
        assertGt(expectedOut, 0, "Router getAmountsOut should return non-zero output");

        // Deal token0 to trader and approve Router
        deal(t0, trader, amountIn);

        uint256 traderT0Before = IERC20(t0).balanceOf(trader);
        uint256 traderT1Before = IERC20(t1).balanceOf(trader);

        vm.startPrank(trader);
        IERC20(t0).approve(router, amountIn);
        uint256[] memory amounts = routerContract.swapExactTokensForTokens(
            amountIn,
            expectedOut,
            routes,
            trader,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Verify returned amounts
        assertEq(amounts[0], amountIn, "First amount should equal amountIn");
        assertEq(amounts[1], expectedOut, "Second amount should equal expectedOut");

        // Verify balances updated correctly
        uint256 traderT0After = IERC20(t0).balanceOf(trader);
        uint256 traderT1After = IERC20(t1).balanceOf(trader);

        assertEq(traderT0After, traderT0Before - amountIn, "Trader token0 should decrease by amountIn");
        assertEq(traderT1After, traderT1Before + expectedOut, "Trader token1 should increase by expectedOut");
    }

    // ========== Router.swap() routes token1 → token0 ==========

    function test_routerSwap_token1ForToken0() public {
        uint256 amountIn = 10 ** IERC20Metadata(t1).decimals();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: t1, to: t0, factory: fpmmFactory});

        uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
        uint256 expectedOut = expectedAmounts[1];
        assertGt(expectedOut, 0, "Router getAmountsOut should return non-zero output");

        deal(t1, trader, amountIn);

        uint256 traderT0Before = IERC20(t0).balanceOf(trader);
        uint256 traderT1Before = IERC20(t1).balanceOf(trader);

        vm.startPrank(trader);
        IERC20(t1).approve(router, amountIn);
        uint256[] memory amounts = routerContract.swapExactTokensForTokens(
            amountIn,
            expectedOut,
            routes,
            trader,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(amounts[0], amountIn, "First amount should equal amountIn");
        assertEq(amounts[1], expectedOut, "Second amount should equal expectedOut");

        uint256 traderT0After = IERC20(t0).balanceOf(trader);
        uint256 traderT1After = IERC20(t1).balanceOf(trader);

        assertEq(traderT1After, traderT1Before - amountIn, "Trader token1 should decrease by amountIn");
        assertEq(traderT0After, traderT0Before + expectedOut, "Trader token0 should increase by expectedOut");
    }

    // ========== Router resolves pool via FactoryRegistry ==========

    function test_routerResolvesPoolViaFactoryRegistry() public {
        // Verify Router's factoryRegistry points to our FactoryRegistry
        assertEq(routerContract.factoryRegistry(), factoryRegistry, "Router.factoryRegistry should match");

        // Verify Router's defaultFactory points to FPMMFactory
        assertEq(routerContract.defaultFactory(), fpmmFactory, "Router.defaultFactory should match FPMMFactory");

        // Verify Router.poolFor resolves to the correct FPMM pool
        address resolvedPool = routerContract.poolFor(t0, t1, fpmmFactory);
        assertEq(resolvedPool, address(fpmm), "Router.poolFor should resolve to the deployed FPMM pool");
    }
}
