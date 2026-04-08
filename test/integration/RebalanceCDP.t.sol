// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {ISystemParams} from "bold/src/Interfaces/ISystemParams.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title RebalanceCDP
 * @notice Tests CDPLiquidityStrategy rebalancing on all CDP-backed FPMM pools
 *         in both directions (sell token0 and sell token1), verifying that
 *         different liquidity sources are exercised:
 *         - Large swap to imbalance pool, then rebalance reduces price difference
 *         - Cooldown is respected (calling again immediately reverts)
 *         - Pool already within threshold cannot be rebalanced
 */
contract RebalanceCDP is V3IntegrationBase {
    ILiquidityStrategy internal strategy;
    address[] internal cdpPools;

    struct TroveParams {
        address borrowerOps;
        address stabilityPool;
        address collToken;
        address gasToken;
        address debtToken;
        uint256 collAmount;
        uint256 debtAmount;
        uint256 interestRate;
        uint256 ethGasComp;
    }

    function setUp() public override {
        super.setUp();
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        strategy = ILiquidityStrategy(cdpLiquidityStrategy);
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
        require(cdpPools.length > 0, "No pools registered with CDPLiquidityStrategy");
    }

    // ========== Helper: seed StabilityPool with funds ==========

    /// @dev Computes all parameters needed to open a trove and seed the StabilityPool.
    ///      Separated from _seedStabilityPool to avoid stack-too-deep.
    function _computeTroveParams(address pool) internal returns (TroveParams memory p) {
        IAddressesRegistry ar = _getAddressesRegistry(pool);
        p.borrowerOps = address(ar.borrowerOperations());
        p.stabilityPool = address(ar.stabilityPool());
        p.collToken = address(ar.collToken());
        p.gasToken = address(ar.gasToken());
        p.debtToken = _getDebtToken(pool);

        ISystemParams sysParams = IStabilityPool(p.stabilityPool).systemParams();
        uint256 price = IPriceFeed(address(ar.priceFeed())).fetchPrice();
        uint256 mcr = IBorrowerOperations(p.borrowerOps).MCR();
        uint8 decimals = IERC20Metadata(p.collToken).decimals();

        p.debtAmount = sysParams.MIN_DEBT() * 10;
        p.collAmount = (p.debtAmount * mcr * 2) / price;
        if (decimals < 18) {
            p.collAmount = p.collAmount / (10 ** (18 - decimals));
        }
        p.collAmount = p.collAmount + (p.collAmount / 100); // +1% buffer
        p.interestRate = sysParams.MIN_ANNUAL_INTEREST_RATE() + 1e16;
        p.ethGasComp = sysParams.ETH_GAS_COMPENSATION();
    }

    /// @dev Opens a trove and deposits all borrowed debt tokens into the StabilityPool
    ///      so the CDPLiquidityStrategy has liquidity to draw from during rebalance.
    function _seedStabilityPool(address pool) internal {
        TroveParams memory p = _computeTroveParams(pool);

        address seeder = makeAddr(string.concat("spSeeder_", IERC20Metadata(p.debtToken).symbol()));
        _dealTokens(p.collToken, seeder, p.collAmount);
        _dealTokens(p.gasToken, seeder, p.ethGasComp);

        vm.startPrank(seeder);
        IERC20(p.collToken).approve(p.borrowerOps, p.collAmount);
        IERC20(p.gasToken).approve(p.borrowerOps, p.ethGasComp);
        IBorrowerOperations(p.borrowerOps)
            .openTrove(
                seeder,
                0,
                p.collAmount,
                p.debtAmount,
                0,
                0,
                p.interestRate,
                p.debtAmount,
                address(0),
                address(0),
                address(0)
            );
        IERC20(p.debtToken).approve(p.stabilityPool, p.debtAmount);
        IStabilityPool(p.stabilityPool).provideToSP(p.debtAmount, false);
        vm.stopPrank();

        // Fund the strategy with collateral so it can subsidize redemption shortfalls
        // during contraction rebalances (where redemption fees reduce collateral received).
        _dealTokens(p.collToken, cdpLiquidityStrategy, p.collAmount);
    }

    // ========== Test: rebalance reduces price difference (both directions) ==========

    function test_rebalance_reducesPriceDifference_sellToken0() public {
        _test_rebalance_reducesPriceDifference(true);
    }

    function test_rebalance_reducesPriceDifference_sellToken1() public {
        _test_rebalance_reducesPriceDifference(false);
    }

    function _test_rebalance_reducesPriceDifference(bool sellToken0) internal {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            address pool = cdpPools[p];
            IFPMM fpmm = IFPMM(pool);
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("rebalTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);

            _seedStabilityPool(pool);

            // Warp past cooldown and refresh oracle rates first, then imbalance pool
            // so the imbalance and rebalance happen at the same timestamp with fresh rates
            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            _ensureImbalanced(pool, trader, sellToken0);

            (,,,,,, uint256 priceDiffBefore) = fpmm.getRebalancingState();

            strategy.rebalance(pool);

            (,,,,,, uint256 priceDiffAfter) = fpmm.getRebalancingState();
            assertLt(priceDiffAfter, priceDiffBefore, string.concat("Price diff should decrease for pool ", idx));
        }
    }

    // ========== Test: cannot rebalance same pool twice in one tx ==========

    /// @notice The strategy uses EIP-1153 transient storage to prevent the same pool
    ///         from being rebalanced more than once per transaction.
    function test_rebalance_cannotRebalanceTwiceInSameTx() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            address pool = cdpPools[p];
            string memory idx = vm.toString(p);
            address trader = makeAddr(string.concat("cooldownTrader_", idx));

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);

            _seedStabilityPool(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            _ensureImbalanced(pool, trader, true);

            strategy.rebalance(pool);

            _ensureImbalanced(pool, trader, true);

            vm.expectRevert(abi.encodeWithSelector(ILiquidityStrategy.LS_CAN_ONLY_REBALANCE_ONCE.selector, pool));
            strategy.rebalance(pool);
        }
    }

    // ========== Test: rebalance reverts when pool is within threshold ==========

    function test_rebalance_revertsWhenWithinThreshold() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            address pool = cdpPools[p];
            IFPMM fpmm = IFPMM(pool);

            (,, uint32 cooldown,,,,,) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);

            _seedStabilityPool(pool);

            vm.warp(block.timestamp + uint256(cooldown) + 1);
            _refreshOracleRates();

            (,,,,, uint16 threshold, uint256 priceDiff) = fpmm.getRebalancingState();
            vm.expectRevert(ILiquidityStrategy.LS_POOL_NOT_REBALANCEABLE.selector);
            strategy.rebalance(pool);
        }
    }
}
