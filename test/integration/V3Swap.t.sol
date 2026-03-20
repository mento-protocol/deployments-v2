// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IVirtualPoolFactory} from "mento-core/interfaces/IVirtualPoolFactory.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IRPool} from "mento-core/swap/router/interfaces/IRPool.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title V3Swap
 * @notice Tests swap flows on all deployed pools (FPMM and VirtualPool):
 *         - Direct FPMM pool swaps (getAmountOut, reserve updates)
 *         - Single-hop swaps through Router for FPMM pools (both directions)
 *         - Single-hop swaps through Router for virtual pools (both directions)
 *         - Multi-hop swaps combining FPMM + VirtualPool
 *         - Pool resolution via FactoryRegistry for both factory types
 */
contract V3Swap is V3IntegrationBase {
    IRouter internal routerContract;
    address[] internal fpmmPools;
    address[] internal vpPools;

    function setUp() public override {
        super.setUp();
        routerContract = IRouter(router);
        fpmmPools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        if (_isCelo()) {
            vpPools = IVirtualPoolFactory(virtualPoolFactory).getAllPools();
            require(vpPools.length > 0, "No virtual pools deployed");
        }
        require(fpmmPools.length > 0, "No FPMM pools deployed");
        _boostFPMMLiquidity();
    }

    /// @dev Mints liquidity into all FPMM pools so that each has at least
    ///      100 full tokens of asset0 and the equivalent amount of asset1, ensuring swap tests don't hit InsufficientLiquidity.
    function _boostFPMMLiquidity() internal {
        address lp = makeAddr("liquidityBooster");
        for (uint256 p = 0; p < fpmmPools.length; p++) {
            IFPMM fpmm = IFPMM(fpmmPools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            (uint256 r0, uint256 r1,) = fpmm.getReserves();

            uint256 minR0 = 100 * (10 ** IERC20Metadata(t0).decimals());
            uint256 minR1 = fpmm.getAmountOut(minR0, t0);

            if (r0 >= minR0 && r1 >= minR1) continue;

            // Calculate multiplier to bring both reserves above minimum
            uint256 mult0 = minR0 > r0 ? (minR0 / r0) + 1 : 0;
            uint256 mult1 = minR1 > r1 ? (minR1 / r1) + 1 : 0;
            uint256 mult = mult0 > mult1 ? mult0 : mult1;
            if (mult == 0) continue;

            // Add liquidity proportional to current reserves to maintain price
            _dealTokens(t0, lp, r0 * mult);
            _dealTokens(t1, lp, r1 * mult);

            vm.startPrank(lp);
            IERC20(t0).transfer(address(fpmm), r0 * mult);
            IERC20(t1).transfer(address(fpmm), r1 * mult);
            fpmm.mint(lp);
            vm.stopPrank();
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Direct FPMM Pool Swaps ═══════════════════
    // ════════════════════════════════════════════════════════════════

    function test_directSwap_token0ForToken1() public {
        for (uint256 p = 0; p < fpmmPools.length; p++) {
            IFPMM fpmm = IFPMM(fpmmPools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("directTrader_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);
            assertGt(expectedOut, 0, string.concat("getAmountOut should return non-zero for pool ", idx));

            _dealTokens(t0, trader, amountIn);
            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, expectedOut, trader, "");
            vm.stopPrank();

            assertEq(
                IERC20(t0).balanceOf(trader),
                traderT0Before - amountIn,
                string.concat("token0 balance mismatch for pool ", idx)
            );
            assertEq(
                IERC20(t1).balanceOf(trader),
                traderT1Before + expectedOut,
                string.concat("token1 balance mismatch for pool ", idx)
            );
        }
    }

    function test_directSwap_token1ForToken0() public {
        for (uint256 p = 0; p < fpmmPools.length; p++) {
            IFPMM fpmm = IFPMM(fpmmPools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("directTrader_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t1).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t1);
            assertGt(expectedOut, 0, string.concat("getAmountOut should return non-zero for pool ", idx));

            _dealTokens(t1, trader, amountIn);
            uint256 traderT0Before = IERC20(t0).balanceOf(trader);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t1).transfer(address(fpmm), amountIn);
            fpmm.swap(expectedOut, 0, trader, "");
            vm.stopPrank();

            assertEq(
                IERC20(t1).balanceOf(trader),
                traderT1Before - amountIn,
                string.concat("token1 balance mismatch for pool ", idx)
            );
            assertEq(
                IERC20(t0).balanceOf(trader),
                traderT0Before + expectedOut,
                string.concat("token0 balance mismatch for pool ", idx)
            );
        }
    }

    function test_directSwap_getAmountOut_matchesActualSwap() public {
        for (uint256 p = 0; p < fpmmPools.length; p++) {
            IFPMM fpmm = IFPMM(fpmmPools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("previewTrader_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 previewOut = fpmm.getAmountOut(amountIn, t0);
            assertGt(previewOut, 0, string.concat("Preview should return non-zero for pool ", idx));

            _dealTokens(t0, trader, amountIn);
            uint256 traderT1Before = IERC20(t1).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, previewOut, trader, "");
            vm.stopPrank();

            uint256 actualOut = IERC20(t1).balanceOf(trader) - traderT1Before;
            assertEq(actualOut, previewOut, string.concat("Preview mismatch for pool ", idx));
        }
    }

    function test_directSwap_updatesReserves() public {
        for (uint256 p = 0; p < fpmmPools.length; p++) {
            IFPMM fpmm = IFPMM(fpmmPools[p]);
            address t0 = fpmm.token0();
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("reserveTrader_", idx));

            uint256 amountIn = 10 ** IERC20Metadata(t0).decimals();
            uint256 expectedOut = fpmm.getAmountOut(amountIn, t0);

            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();

            _dealTokens(t0, trader, amountIn);
            vm.startPrank(trader);
            IERC20(t0).transfer(address(fpmm), amountIn);
            fpmm.swap(0, expectedOut, trader, "");
            vm.stopPrank();

            uint256 protocolFeeAmount = (amountIn * fpmm.protocolFee()) / 10_000;

            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();

            assertEq(
                r0After, r0Before + amountIn - protocolFeeAmount, string.concat("reserve0 mismatch for pool ", idx)
            );
            assertEq(r1After, r1Before - expectedOut, string.concat("reserve1 mismatch for pool ", idx));
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Router FPMM Pool Swaps ═══════════════════
    // ════════════════════════════════════════════════════════════════

    function test_fpmmSwap_token0ForToken1() public {
        for (uint256 i = 0; i < fpmmPools.length; i++) {
            _test_singleHopSwap(fpmmPools[i], fpmmFactory, true, string.concat("fpmm_", vm.toString(i)));
        }
    }

    function test_fpmmSwap_token1ForToken0() public {
        for (uint256 i = 0; i < fpmmPools.length; i++) {
            _test_singleHopSwap(fpmmPools[i], fpmmFactory, false, string.concat("fpmm_", vm.toString(i)));
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Virtual Pool Swaps ════════════════════════
    // ════════════════════════════════════════════════════════════════

    function test_virtualPoolSwap_token0ForToken1() public {
        for (uint256 i = 0; i < vpPools.length; i++) {
            _test_singleHopSwap(vpPools[i], virtualPoolFactory, true, string.concat("vp_", vm.toString(i)));
        }
    }

    function test_virtualPoolSwap_token1ForToken0() public {
        for (uint256 i = 0; i < vpPools.length; i++) {
            _test_singleHopSwap(vpPools[i], virtualPoolFactory, false, string.concat("vp_", vm.toString(i)));
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Multi-Hop Swaps ══════════════════════════
    // ════════════════════════════════════════════════════════════════

    /// @notice 2-hop route: FPMM(tokenA→tokenB) → VirtualPool(tokenB→tokenC)
    function test_multiHop_fpmmThenVirtualPool() public onlyCelo {
        (address tokenA, address tokenB, address tokenC, address factory1, address factory2) =
            _findMultiHopAcrossFactories(fpmmPools, fpmmFactory, vpPools, virtualPoolFactory);
        require(tokenA != address(0), "No multi-hop route found: FPMM -> VirtualPool");
        _test_multiHopSwap(tokenA, tokenB, tokenC, factory1, factory2);
    }

    /// @notice 2-hop route: VirtualPool(tokenA→tokenB) → FPMM(tokenB→tokenC)
    function test_multiHop_virtualPoolThenFpmm() public onlyCelo {
        (address tokenA, address tokenB, address tokenC, address factory1, address factory2) =
            _findMultiHopAcrossFactories(vpPools, virtualPoolFactory, fpmmPools, fpmmFactory);
        require(tokenA != address(0), "No multi-hop route found: VirtualPool -> FPMM");
        _test_multiHopSwap(tokenA, tokenB, tokenC, factory1, factory2);
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Pool Resolution ══════════════════════════
    // ════════════════════════════════════════════════════════════════

    function test_routerResolvesPoolViaFactoryRegistry() public view {
        assertEq(routerContract.factoryRegistry(), factoryRegistry, "Router.factoryRegistry mismatch");
        assertEq(routerContract.defaultFactory(), fpmmFactory, "Router.defaultFactory mismatch");

        // FPMM pools
        for (uint256 i = 0; i < fpmmPools.length; i++) {
            address resolved =
                routerContract.poolFor(IFPMM(fpmmPools[i]).token0(), IFPMM(fpmmPools[i]).token1(), fpmmFactory);
            assertEq(resolved, fpmmPools[i], string.concat("FPMM poolFor mismatch at index ", vm.toString(i)));
        }

        // Virtual pools
        for (uint256 i = 0; i < vpPools.length; i++) {
            address resolved =
                routerContract.poolFor(IRPool(vpPools[i]).token0(), IRPool(vpPools[i]).token1(), virtualPoolFactory);
            assertEq(resolved, vpPools[i], string.concat("VP poolFor mismatch at index ", vm.toString(i)));
        }
    }

    function test_virtualPoolFactory_isApproved() public onlyCelo {
        assertTrue(
            IFactoryRegistry(factoryRegistry).isPoolFactoryApproved(virtualPoolFactory),
            "VirtualPoolFactory not approved in FactoryRegistry"
        );
    }

    function test_virtualPools_haveValidMetadata() public view {
        for (uint256 i = 0; i < vpPools.length; i++) {
            IRPool vp = IRPool(vpPools[i]);
            string memory idx = vm.toString(i);

            address t0 = vp.token0();
            address t1 = vp.token1();
            assertNotEq(t0, address(0), string.concat("VP token0 is zero at index ", idx));
            assertNotEq(t1, address(0), string.concat("VP token1 is zero at index ", idx));
            assertLt(uint160(t0), uint160(t1), string.concat("VP tokens not sorted at index ", idx));

            (uint256 r0, uint256 r1,) = vp.getReserves();
            assertGt(r0, 0, string.concat("VP reserve0 is zero at index ", idx));
            assertGt(r1, 0, string.concat("VP reserve1 is zero at index ", idx));
        }
    }

    // ════════════════════════════════════════════════════════════════
    // ═══════════════════ Internal Helpers ═════════════════════════
    // ════════════════════════════════════════════════════════════════

    function _test_singleHopSwap(address pool, address factory, bool sellToken0, string memory label) internal {
        IRPool rpool = IRPool(pool);
        address tokenIn = sellToken0 ? rpool.token0() : rpool.token1();
        address tokenOut = sellToken0 ? rpool.token1() : rpool.token0();
        address trader = makeAddr(string.concat("trader_", label, sellToken0 ? "_0" : "_1"));

        uint256 amountIn = 10 ** IERC20Metadata(tokenIn).decimals();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: tokenIn, to: tokenOut, factory: factory});

        uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
        assertEq(expectedAmounts.length, 2, string.concat("Expected 2 amounts for ", label));
        uint256 expectedOut = expectedAmounts[1];
        assertGt(expectedOut, 0, string.concat("getAmountsOut zero for ", label));

        _dealTokens(tokenIn, trader, amountIn);

        uint256 traderInBefore = IERC20(tokenIn).balanceOf(trader);
        uint256 traderOutBefore = IERC20(tokenOut).balanceOf(trader);

        vm.startPrank(trader);
        IERC20(tokenIn).approve(router, amountIn);
        uint256[] memory amounts =
            routerContract.swapExactTokensForTokens(amountIn, expectedOut, routes, trader, block.timestamp + 1 hours);
        vm.stopPrank();

        assertEq(amounts[0], amountIn, string.concat("amountIn mismatch for ", label));
        assertEq(amounts[1], expectedOut, string.concat("amountOut mismatch for ", label));
        assertEq(
            IERC20(tokenIn).balanceOf(trader), traderInBefore - amountIn, string.concat("tokenIn balance for ", label)
        );
        assertEq(
            IERC20(tokenOut).balanceOf(trader),
            traderOutBefore + expectedOut,
            string.concat("tokenOut balance for ", label)
        );
    }

    function _test_multiHopSwap(address tokenA, address tokenB, address tokenC, address factory1, address factory2)
        internal
    {
        address trader = makeAddr("multiHopTrader");
        uint256 amountIn = 10 ** IERC20Metadata(tokenA).decimals();

        IRouter.Route[] memory routes = new IRouter.Route[](2);
        routes[0] = IRouter.Route({from: tokenA, to: tokenB, factory: factory1});
        routes[1] = IRouter.Route({from: tokenB, to: tokenC, factory: factory2});

        uint256[] memory expectedAmounts = routerContract.getAmountsOut(amountIn, routes);
        assertEq(expectedAmounts.length, 3, "Expected 3 amounts for 2-hop route");
        assertGt(expectedAmounts[1], 0, "Hop 1 output should be non-zero");
        assertGt(expectedAmounts[2], 0, "Hop 2 output should be non-zero");

        _dealTokens(tokenA, trader, amountIn);
        uint256 traderCBefore = IERC20(tokenC).balanceOf(trader);

        vm.startPrank(trader);
        IERC20(tokenA).approve(router, amountIn);
        uint256[] memory amounts = routerContract.swapExactTokensForTokens(
            amountIn, expectedAmounts[2], routes, trader, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertEq(amounts[0], amountIn, "Multi-hop amountIn mismatch");
        assertEq(amounts[2], expectedAmounts[2], "Multi-hop final output mismatch");
        assertEq(IERC20(tokenC).balanceOf(trader), traderCBefore + amounts[2], "Multi-hop tokenC balance mismatch");
    }

    /// @dev Searches for a 2-hop route across two sets of pools from different factories.
    ///      Returns (tokenA, tokenB, tokenC, factory1, factory2) or (0,0,0,0,0) if none found.
    function _findMultiHopAcrossFactories(
        address[] memory pools1,
        address factory1,
        address[] memory pools2,
        address factory2
    ) internal view returns (address tokenA, address tokenB, address tokenC, address f1, address f2) {
        for (uint256 i = 0; i < pools1.length; i++) {
            for (uint256 j = 0; j < pools2.length; j++) {
                (tokenA, tokenB, tokenC) = _findSharedToken(pools1[i], pools2[j]);
                if (tokenA != address(0)) {
                    return (tokenA, tokenB, tokenC, factory1, factory2);
                }
            }
        }
    }

    /// @dev Finds a shared token between two pools to form a multi-hop route.
    ///      Returns (tokenA, sharedToken, tokenC) or (0,0,0) if no shared token or tokenA==tokenC.
    function _findSharedToken(address pool1, address pool2)
        internal
        view
        returns (address tokenA, address tokenB, address tokenC)
    {
        address p1t0 = IRPool(pool1).token0();
        address p1t1 = IRPool(pool1).token1();
        address p2t0 = IRPool(pool2).token0();
        address p2t1 = IRPool(pool2).token1();

        if (p1t0 == p2t0 && p1t1 != p2t1) return (p1t1, p1t0, p2t1);
        if (p1t0 == p2t1 && p1t1 != p2t0) return (p1t1, p1t0, p2t0);
        if (p1t1 == p2t0 && p1t0 != p2t1) return (p1t0, p1t1, p2t1);
        if (p1t1 == p2t1 && p1t0 != p2t0) return (p1t0, p1t1, p2t0);
    }
}
