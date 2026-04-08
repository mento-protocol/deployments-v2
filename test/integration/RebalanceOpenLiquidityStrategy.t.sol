// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";

/**
 * @title RebalanceOpenLiquidityStrategy
 * @notice Tests OpenLiquidityStrategy rebalancing on all OLS FPMM pools.
 *         Only runs on Monad (skipped on Celo).
 *
 *         Verifies:
 *         - Rebalance reduces price difference in both directions
 *         - Double-rebalance in same tx is blocked (transient storage guard)
 *         - Pool within threshold cannot be rebalanced
 */
contract RebalanceOpenLiquidityStrategy is V3IntegrationBase {
    ILiquidityStrategy internal strategy;
    address internal openLiquidityStrategy;
    address[] internal olsPools;

    address constant REBALANCER = address(0xBEEF);

    modifier onlyMonad() {
        if (_isCelo()) {
            vm.skip(true);
            return;
        }
        _;
    }

    function setUp() public override {
        super.setUp();

        // OLS is only deployed on Monad; skip entirely on Celo
        if (_isCelo()) return;

        openLiquidityStrategy = lookupProxyOrFail("OpenLiquidityStrategy");
        strategy = ILiquidityStrategy(openLiquidityStrategy);
        olsPools = strategy.getPools();
    }

    // ========== Helper: fund rebalancer with tokens for OLS rebalance ==========

    /// @dev For OLS the rebalancer (caller) must provide liquidity.
    ///      Funds the rebalancer with both tokens since the rebalance direction
    ///      determines which token is needed (debt for expansion, collateral for contraction).
    function _fundRebalancer(address pool) internal {
        address token0 = IFPMM(pool).token0();
        address token1 = IFPMM(pool).token1();
        (uint256 r0, uint256 r1,) = IFPMM(pool).getReserves();

        _dealTokens(token0, REBALANCER, r0 * 10);
        _dealTokens(token1, REBALANCER, r1 * 10);

        vm.startPrank(REBALANCER);
        IERC20(token0).approve(openLiquidityStrategy, type(uint256).max);
        IERC20(token1).approve(openLiquidityStrategy, type(uint256).max);
        vm.stopPrank();
    }

    // ========== Test: pools exist ==========

    function test_olsPools_exist() public onlyMonad {
        assertGt(olsPools.length, 0, "No pools registered with OpenLiquidityStrategy");
    }

    // ========== Test: strategy is enabled on each FPMM ==========

    function test_olsPools_strategyEnabledOnFPMM() public onlyMonad {
        for (uint256 i = 0; i < olsPools.length; i++) {
            assertTrue(
                IFPMM(olsPools[i]).liquidityStrategy(openLiquidityStrategy),
                string.concat("OpenLiquidityStrategy not enabled on FPMM pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Test: pool config matches config ==========

    function test_olsPools_poolConfig_valid() public onlyMonad {
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < olsPools.length; i++) {
            (
                ,,
                uint32 rebalanceCooldown,
                address protocolFeeRecipient,
                uint64 lsIncentiveExpansion,
                uint64 protocolIncentiveExpansion,
                uint64 lsIncentiveContraction,
                uint64 protocolIncentiveContraction
            ) = IPoolConfigReader(openLiquidityStrategy).poolConfigs(olsPools[i]);

            IMentoConfig.LiquidityStrategyPoolConfig memory expected = _findOlsConfig(fpmmConfigs, olsPools[i]);
            string memory idx = vm.toString(i);

            assertEq(rebalanceCooldown, expected.cooldown, string.concat("cooldown mismatch at index ", idx));
            assertEq(
                protocolFeeRecipient,
                expected.protocolFeeRecipient,
                string.concat("protocolFeeRecipient mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveExpansion,
                expected.liquiditySourceIncentiveExpansion,
                string.concat("lsIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveExpansion,
                expected.protocolIncentiveExpansion,
                string.concat("protocolIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveContraction,
                expected.liquiditySourceIncentiveContraction,
                string.concat("lsIncentiveContraction mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveContraction,
                expected.protocolIncentiveContraction,
                string.concat("protocolIncentiveContraction mismatch at index ", idx)
            );
        }
    }

    // ========== Test: rebalance reduces price difference (both directions) ==========

    function test_rebalance_reducesPriceDifference_sellToken0() public onlyMonad {
        _test_rebalance_reducesPriceDifference(true);
    }

    function test_rebalance_reducesPriceDifference_sellToken1() public onlyMonad {
        _test_rebalance_reducesPriceDifference(false);
    }

    function _test_rebalance_reducesPriceDifference(bool sellToken0) internal {
        for (uint256 p = 0; p < olsPools.length; p++) {
            address pool = olsPools[p];
            IFPMM fpmm = IFPMM(pool);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("olsTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(openLiquidityStrategy).poolConfigs(pool);

            _fundRebalancer(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            _ensureImbalanced(pool, trader, sellToken0);

            (,,,,,, uint256 priceDiffBefore) = fpmm.getRebalancingState();

            vm.prank(REBALANCER);
            strategy.rebalance(pool);

            (,,,,,, uint256 priceDiffAfter) = fpmm.getRebalancingState();
            assertLt(priceDiffAfter, priceDiffBefore, string.concat("Price diff should decrease for pool ", idx));
        }
    }

    // ========== Test: cannot rebalance same pool twice in one tx ==========

    function test_rebalance_cannotRebalanceTwiceInSameTx() public onlyMonad {
        for (uint256 p = 0; p < olsPools.length; p++) {
            address pool = olsPools[p];
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("olsCooldownTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(openLiquidityStrategy).poolConfigs(pool);

            _fundRebalancer(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            _ensureImbalanced(pool, trader, true);

            vm.prank(REBALANCER);
            strategy.rebalance(pool);

            // Warp to reset L0 trading limit window before re-imbalancing
            vm.warp(block.timestamp + 5 minutes + 1);
            _refreshOracleRates();
            _ensureImbalanced(pool, trader, true);

            vm.expectRevert(abi.encodeWithSelector(ILiquidityStrategy.LS_CAN_ONLY_REBALANCE_ONCE.selector, pool));
            vm.prank(REBALANCER);
            strategy.rebalance(pool);
        }
    }

    // ========== Test: rebalance reverts when pool is within threshold ==========

    function test_rebalance_revertsWhenWithinThreshold() public onlyMonad {
        for (uint256 p = 0; p < olsPools.length; p++) {
            address pool = olsPools[p];
            IFPMM fpmm = IFPMM(pool);

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(openLiquidityStrategy).poolConfigs(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            (,,,,, uint16 threshold, uint256 priceDiff) = fpmm.getRebalancingState();

            vm.expectRevert(ILiquidityStrategy.LS_POOL_NOT_REBALANCEABLE.selector);
            vm.prank(REBALANCER);
            strategy.rebalance(pool);
        }
    }

    // ========== Internal Helpers ==========

    function _findOlsConfig(IMentoConfig.FPMMConfig[] memory fpmmConfigs, address pool)
        internal
        view
        returns (IMentoConfig.LiquidityStrategyPoolConfig memory)
    {
        address t0 = IFPMM(pool).token0();
        address t1 = IFPMM(pool).token1();
        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            if (
                (fpmmConfigs[i].token0 == t0 && fpmmConfigs[i].token1 == t1)
                    || (fpmmConfigs[i].token0 == t1 && fpmmConfigs[i].token1 == t0)
            ) {
                return fpmmConfigs[i].liquidityStrategyConfig;
            }
        }
        revert("OLS config not found for token pair");
    }
}
