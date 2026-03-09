// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ITradingLimitsV2} from "mento-core/interfaces/ITradingLimitsV2.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";

/**
 * @title FPMMTradingLimits
 * @notice Verifies per-token trading limits (L0 = 5-minute, L1 = 1-day) are correctly
 *         configured and enforced on all deployed FPMM pools.
 */
contract FPMMTradingLimits is V3IntegrationBase {
    address[] internal pools;
    uint256 constant TIMESTEP0 = 300; // 5 minutes

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        require(pools.length > 0, "No FPMM pools deployed");
        _boostLiquidity();
    }

    // ========== Test: Limits Configured ==========

    /// @notice For each pool, at least one token must have non-zero trading limits.
    ///         When both L0 and L1 are set, L1 > L0.
    function test_allPools_tradingLimitsConfigured() public view {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            string memory idx = vm.toString(p);

            (ITradingLimitsV2.Config memory cfg0,) = fpmm.getTradingLimits(fpmm.token0());
            (ITradingLimitsV2.Config memory cfg1,) = fpmm.getTradingLimits(fpmm.token1());

            bool token0HasLimits = cfg0.limit0 > 0 || cfg0.limit1 > 0;
            bool token1HasLimits = cfg1.limit0 > 0 || cfg1.limit1 > 0;

            assertTrue(
                token0HasLimits || token1HasLimits,
                string.concat("Pool ", idx, ": no trading limits configured on either token")
            );

            if (cfg0.limit0 > 0 && cfg0.limit1 > 0) {
                assertGt(
                    uint256(int256(cfg0.limit1)),
                    uint256(int256(cfg0.limit0)),
                    string.concat("Pool ", idx, " token0: limit1 must be > limit0")
                );
            }

            if (cfg1.limit0 > 0 && cfg1.limit1 > 0) {
                assertGt(
                    uint256(int256(cfg1.limit1)),
                    uint256(int256(cfg1.limit0)),
                    string.concat("Pool ", idx, " token1: limit1 must be > limit0")
                );
            }
        }
    }

    // ========== Test: Limits Match Config ==========

    /// @notice On-chain trading limits must match the expected config values
    ///         (accounting for token sorting and 15-decimal internal scaling).
    function test_allPools_tradingLimitsMatchConfig() public view {
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            address t0 = fpmm.token0();
            address t1 = fpmm.token1();
            string memory idx = vm.toString(p);

            IMentoConfig.FPMMConfig memory cfg = _findFPMMConfig(fpmmConfigs, t0, t1);
            IMentoConfig.FPMMTradingLimitsConfig memory limits = cfg.tradingLimits;

            uint256 expectedT0Limit0 = limits.token0Limit0;
            uint256 expectedT0Limit1 = limits.token0Limit1;
            uint256 expectedT1Limit0 = limits.token1Limit0;
            uint256 expectedT1Limit1 = limits.token1Limit1;

            uint8 decimals0 = IERC20Metadata(t0).decimals();
            uint8 decimals1 = IERC20Metadata(t1).decimals();

            (ITradingLimitsV2.Config memory onChain0,) = fpmm.getTradingLimits(t0);
            (ITradingLimitsV2.Config memory onChain1,) = fpmm.getTradingLimits(t1);

            assertEq(
                onChain0.limit0,
                _toInternalPrecision(expectedT0Limit0, decimals0),
                string.concat("Pool ", idx, " token0 limit0 mismatch")
            );
            assertEq(
                onChain0.limit1,
                _toInternalPrecision(expectedT0Limit1, decimals0),
                string.concat("Pool ", idx, " token0 limit1 mismatch")
            );
            assertEq(
                onChain1.limit0,
                _toInternalPrecision(expectedT1Limit0, decimals1),
                string.concat("Pool ", idx, " token1 limit0 mismatch")
            );
            assertEq(
                onChain1.limit1,
                _toInternalPrecision(expectedT1Limit1, decimals1),
                string.concat("Pool ", idx, " token1 limit1 mismatch")
            );
        }
    }

    // ========== Test: L0 Limit Enforcement ==========

    /// @notice Swapping an amount that exceeds the L0 limit must revert.
    function test_allPools_L0LimitEnforcement() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("l0trader_", idx));

            (address tokenIn, uint256 l0LimitTokenDecimals) = _findTokenWithL0Limit(fpmm);
            require(tokenIn != address(0), string.concat("Pool ", idx, ": no token with L0 limit"));

            // Swap amount = L0 limit + 10% to ensure post-fee netflow exceeds limit
            uint256 amountIn = l0LimitTokenDecimals + (l0LimitTokenDecimals / 10);

            uint256 expectedOut = fpmm.getAmountOut(amountIn, tokenIn);
            require(expectedOut > 0, string.concat("Pool ", idx, ": getAmountOut returned zero for L0 test"));

            bool sellToken0 = tokenIn == fpmm.token0();

            deal(tokenIn, trader, amountIn);

            vm.startPrank(trader);
            IERC20(tokenIn).transfer(address(fpmm), amountIn);
            vm.expectRevert(ITradingLimitsV2.L0LimitExceeded.selector);
            if (sellToken0) {
                fpmm.swap(0, expectedOut, trader, "");
            } else {
                fpmm.swap(expectedOut, 0, trader, "");
            }
            vm.stopPrank();
        }
    }

    // ========== Test: Swap Within Limits ==========

    /// @notice A small swap (well within L0) should succeed and update netflow state.
    function test_allPools_swapWithinLimits() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("withinTrader_", idx));

            (address tokenIn, uint256 l0LimitTokenDecimals) = _findTokenWithL0Limit(fpmm);
            require(tokenIn != address(0), string.concat("Pool ", idx, ": no token with L0 limit"));

            // 10% of L0 limit — well within bounds
            uint256 amountIn = l0LimitTokenDecimals / 10;
            require(amountIn > 0, string.concat("Pool ", idx, ": L0 limit too small for test"));

            uint256 expectedOut = fpmm.getAmountOut(amountIn, tokenIn);
            require(expectedOut > 0, string.concat("Pool ", idx, ": getAmountOut returned zero"));

            bool sellToken0 = tokenIn == fpmm.token0();
            address tokenOut = sellToken0 ? fpmm.token1() : fpmm.token0();

            (, ITradingLimitsV2.State memory stateBefore) = fpmm.getTradingLimits(tokenIn);

            deal(tokenIn, trader, amountIn);
            uint256 traderOutBefore = IERC20(tokenOut).balanceOf(trader);

            vm.startPrank(trader);
            IERC20(tokenIn).transfer(address(fpmm), amountIn);
            if (sellToken0) {
                fpmm.swap(0, expectedOut, trader, "");
            } else {
                fpmm.swap(expectedOut, 0, trader, "");
            }
            vm.stopPrank();

            assertEq(
                IERC20(tokenOut).balanceOf(trader),
                traderOutBefore + expectedOut,
                string.concat("Pool ", idx, ": trader did not receive expected output")
            );

            (, ITradingLimitsV2.State memory stateAfter) = fpmm.getTradingLimits(tokenIn);
            assertGt(
                stateAfter.netflow0,
                stateBefore.netflow0,
                string.concat("Pool ", idx, ": netflow0 should increase for tokenIn")
            );
        }
    }

    // ========== Test: L0 Limit Reset ==========

    /// @notice Swap near the L0 limit, warp past TIMESTEP0, swap again to prove window reset.
    function test_allPools_L0LimitReset() public {
        for (uint256 p = 0; p < pools.length; p++) {
            IFPMM fpmm = IFPMM(pools[p]);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("resetTrader_", idx));

            (address tokenIn, uint256 l0LimitTokenDecimals) = _findTokenWithL0Limit(fpmm);
            require(tokenIn != address(0), string.concat("Pool ", idx, ": no token with L0 limit"));

            // First swap: 80% of L0 limit
            uint256 firstAmount = (l0LimitTokenDecimals * 80) / 100;
            require(firstAmount > 0, string.concat("Pool ", idx, ": L0 limit too small for reset test"));

            uint256 firstExpectedOut = fpmm.getAmountOut(firstAmount, tokenIn);
            require(firstExpectedOut > 0, string.concat("Pool ", idx, ": getAmountOut zero for first swap"));

            bool sellToken0 = tokenIn == fpmm.token0();
            address tokenOut = sellToken0 ? fpmm.token1() : fpmm.token0();

            deal(tokenIn, trader, firstAmount);
            vm.startPrank(trader);
            IERC20(tokenIn).transfer(address(fpmm), firstAmount);
            if (sellToken0) {
                fpmm.swap(0, firstExpectedOut, trader, "");
            } else {
                fpmm.swap(firstExpectedOut, 0, trader, "");
            }
            vm.stopPrank();

            // Warp past L0 window
            vm.warp(block.timestamp + TIMESTEP0 + 1);
            _refreshOracleRates();

            // Second swap: same amount should succeed after window reset
            uint256 secondAmount = firstAmount;
            uint256 secondExpectedOut = fpmm.getAmountOut(secondAmount, tokenIn);
            require(secondExpectedOut > 0, string.concat("Pool ", idx, ": getAmountOut zero for second swap"));

            uint256 traderOutBefore = IERC20(tokenOut).balanceOf(trader);

            deal(tokenIn, trader, secondAmount);
            vm.startPrank(trader);
            IERC20(tokenIn).transfer(address(fpmm), secondAmount);
            if (sellToken0) {
                fpmm.swap(0, secondExpectedOut, trader, "");
            } else {
                fpmm.swap(secondExpectedOut, 0, trader, "");
            }
            vm.stopPrank();

            assertEq(
                IERC20(tokenOut).balanceOf(trader),
                traderOutBefore + secondExpectedOut,
                string.concat("Pool ", idx, ": second swap after L0 reset should succeed")
            );
        }
    }

    // ========== Internal Helpers ==========

    /// @dev Ensures every pool has enough reserves to test against its L0 limits.
    ///      For each token with an L0 limit, targets reserves >= 3x the L0 limit
    ///      so that a swap of 110% of L0 is comfortably within pool capacity.
    function _boostLiquidity() internal {
        address lp = makeAddr("liquidityBooster");
        for (uint256 p = 0; p < pools.length; p++) {
            _boostPoolLiquidity(IFPMM(pools[p]), lp);
        }
    }

    function _boostPoolLiquidity(IFPMM fpmm, address lp) internal {
        address t0 = fpmm.token0();
        address t1 = fpmm.token1();
        (uint256 r0, uint256 r1,) = fpmm.getReserves();

        uint256 neededR0 = _neededReserve(fpmm, t0);
        uint256 neededR1 = _neededReserve(fpmm, t1);

        if (r0 >= neededR0 && r1 >= neededR1) return;

        // Calculate multiplier to bring both reserves above their needed levels
        uint256 mult0 = neededR0 > r0 ? (neededR0 / r0) + 1 : 0;
        uint256 mult1 = neededR1 > r1 ? (neededR1 / r1) + 1 : 0;
        uint256 mult = mult0 > mult1 ? mult0 : mult1;
        if (mult == 0) return;

        // Add liquidity proportional to current reserves to maintain price
        deal(t0, lp, r0 * mult);
        deal(t1, lp, r1 * mult);

        vm.startPrank(lp);
        IERC20(t0).transfer(address(fpmm), r0 * mult);
        IERC20(t1).transfer(address(fpmm), r1 * mult);
        fpmm.mint(lp);
        vm.stopPrank();
    }

    /// @dev Returns the minimum reserve a token needs (3x its L0 limit), or 0 if no L0 limit.
    function _neededReserve(IFPMM fpmm, address token) internal view returns (uint256) {
        (ITradingLimitsV2.Config memory cfg,) = fpmm.getTradingLimits(token);
        if (cfg.limit0 <= 0) return 0;
        return _toTokenDecimals(uint256(int256(cfg.limit0)) * 3, IERC20Metadata(token).decimals());
    }

    /// @dev Finds the FPMMConfig for a token pair (handles both orderings).
    function _findFPMMConfig(IMentoConfig.FPMMConfig[] memory fpmmConfigs, address t0, address t1)
        internal
        pure
        returns (IMentoConfig.FPMMConfig memory)
    {
        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            if (
                (fpmmConfigs[i].token0 == t0 && fpmmConfigs[i].token1 == t1)
                    || (fpmmConfigs[i].token0 == t1 && fpmmConfigs[i].token1 == t0)
            ) {
                return fpmmConfigs[i];
            }
        }
        revert("FPMMConfig not found for token pair");
    }

    /// @dev Returns a token with an active L0 limit and its L0 value in token decimals.
    ///      Prefers token0 if both have L0 limits.
    function _findTokenWithL0Limit(IFPMM fpmm) internal view returns (address token, uint256 l0LimitTokenDecimals) {
        address t0 = fpmm.token0();
        address t1 = fpmm.token1();

        (ITradingLimitsV2.Config memory cfg0,) = fpmm.getTradingLimits(t0);
        if (cfg0.limit0 > 0) {
            return (t0, _toTokenDecimals(uint256(int256(cfg0.limit0)), IERC20Metadata(t0).decimals()));
        }

        (ITradingLimitsV2.Config memory cfg1,) = fpmm.getTradingLimits(t1);
        if (cfg1.limit0 > 0) {
            return (t1, _toTokenDecimals(uint256(int256(cfg1.limit0)), IERC20Metadata(t1).decimals()));
        }
    }

    /// @dev Converts a value in token decimals to 15-decimal internal precision.
    function _toInternalPrecision(uint256 value, uint8 decimals) internal pure returns (int120) {
        if (value == 0) return 0;
        if (decimals > 15) {
            return int120(int256(value / (10 ** (decimals - 15))));
        } else {
            return int120(int256(value * (10 ** (15 - decimals))));
        }
    }

    /// @dev Converts a 15-decimal internal value to token decimals.
    function _toTokenDecimals(uint256 value, uint8 decimals) internal pure returns (uint256) {
        if (decimals > 15) {
            return value * (10 ** (decimals - 15));
        } else {
            return value / (10 ** (15 - decimals));
        }
    }
}
