// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {ISystemParams} from "bold/src/Interfaces/ISystemParams.sol";
import {LatestTroveData} from "bold/src/Types/LatestTroveData.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title CDPOperations
 * @notice Tests CDP user operations across all deployed CDP pools:
 *         opening troves, StabilityPool deposits/withdrawals, liquidations, and interest accrual.
 */
contract CDPOperations is V3IntegrationBase {
    address[] internal cdpPools;

    /// @dev Holds resolved contract addresses for a CDP pool
    struct PoolContracts {
        address borrowerOps;
        address troveManager;
        address stabilityPool;
        address priceFeed;
        address collToken;
        address gasToken;
        address debtToken;
    }

    function setUp() public override {
        super.setUp();
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
        require(cdpPools.length > 0, "No CDP pools");
    }

    // ========== Open Trove ==========

    function test_openTrove_successful() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address user = makeAddr(string.concat("troveOpener_", idx));
            uint256 debtBefore = IERC20(c.debtToken).balanceOf(user);

            (uint256 troveId, uint256 debtAmount, uint256 collAmount) = _openTroveForUser(user, c);

            ITroveManager.Status status = ITroveManager(c.troveManager).getTroveStatus(troveId);
            assertEq(
                uint256(status), uint256(ITroveManager.Status.active), string.concat("Trove not active for pool ", idx)
            );

            uint256 debtAfter = IERC20(c.debtToken).balanceOf(user);
            assertEq(debtAfter - debtBefore, debtAmount, string.concat("Debt token balance mismatch for pool ", idx));

            LatestTroveData memory data = ITroveManager(c.troveManager).getLatestTroveData(troveId);
            assertEq(data.entireColl, collAmount, string.concat("Trove collateral mismatch for pool ", idx));
        }
    }

    // ========== StabilityPool Deposit ==========

    function test_stabilityPool_deposit() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address user = makeAddr(string.concat("spDepositor_", idx));
            (, uint256 debtAmount,) = _openTroveForUser(user, c);

            uint256 depositAmount = debtAmount / 2;
            uint256 depositBefore = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
            uint256 balanceBefore = IERC20(c.debtToken).balanceOf(user);

            vm.startPrank(user);
            IERC20(c.debtToken).approve(c.stabilityPool, depositAmount);
            IStabilityPool(c.stabilityPool).provideToSP(depositAmount, false);
            vm.stopPrank();

            uint256 depositAfter = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
            assertEq(depositAfter - depositBefore, depositAmount, string.concat("SP deposit mismatch for pool ", idx));

            uint256 balanceAfter = IERC20(c.debtToken).balanceOf(user);
            assertEq(
                balanceBefore - balanceAfter,
                depositAmount,
                string.concat("Debt token transfer mismatch for pool ", idx)
            );
        }
    }

    // ========== StabilityPool Withdrawal ==========

    function test_stabilityPool_withdrawal() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address user = makeAddr(string.concat("spWithdrawer_", idx));
            (, uint256 debtAmount,) = _openTroveForUser(user, c);

            uint256 depositAmount = debtAmount / 2;
            vm.startPrank(user);
            IERC20(c.debtToken).approve(c.stabilityPool, depositAmount);
            IStabilityPool(c.stabilityPool).provideToSP(depositAmount, false);
            vm.stopPrank();

            uint256 depositBefore = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
            uint256 balanceBefore = IERC20(c.debtToken).balanceOf(user);

            uint256 withdrawAmount = depositAmount / 2;
            vm.prank(user);
            IStabilityPool(c.stabilityPool).withdrawFromSP(withdrawAmount, false);

            uint256 depositAfter = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
            uint256 balanceAfter = IERC20(c.debtToken).balanceOf(user);

            assertLt(depositAfter, depositBefore, string.concat("SP deposit should decrease for pool ", idx));
            assertEq(
                balanceAfter - balanceBefore, withdrawAmount, string.concat("Withdrawal amount mismatch for pool ", idx)
            );
        }
    }

    // ========== Liquidation ==========

    function test_liquidation_undercollateralizedTrove() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address victim = makeAddr(string.concat("liquidationVictim_", idx));
            (uint256 victimTroveId,,) = _openTroveAtCR(victim, c, 115);

            _openTroveAndDepositToSP(makeAddr(string.concat("liquidationDepositor_", idx)), c);

            uint256 droppedPrice = _mockLowerPrice(c, 75);

            uint256 icr = ITroveManager(c.troveManager).getCurrentICR(victimTroveId, droppedPrice);
            assertLt(
                icr,
                IBorrowerOperations(c.borrowerOps).MCR(),
                string.concat("Trove should be undercollateralized for pool ", idx)
            );

            _liquidateTrove(c, victimTroveId);

            ITroveManager.Status status = ITroveManager(c.troveManager).getTroveStatus(victimTroveId);
            assertEq(
                uint256(status),
                uint256(ITroveManager.Status.closedByLiquidation),
                string.concat("Trove should be closed by liquidation for pool ", idx)
            );

            vm.clearMockedCalls();
        }
    }

    // ========== Interest Accrual ==========

    function test_interestAccrual() public {
        // Fix this: 30 days jump can hit a Weekend here also needs an oracleRefresh
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address user = makeAddr(string.concat("interestUser_", idx));
            (uint256 troveId,,) = _openTroveForUser(user, c);

            uint256 debtBefore = ITroveManager(c.troveManager).getLatestTroveData(troveId).entireDebt;

            vm.warp(block.timestamp + 30 days);

            uint256 debtAfter = ITroveManager(c.troveManager).getLatestTroveData(troveId).entireDebt;
            assertGt(debtAfter, debtBefore, string.concat("Debt should increase after 30 days for pool ", idx));
        }
    }

    // ========== StabilityPool Collateral Gains ==========

    function test_stabilityPool_collateralGainsAfterLiquidation() public {
        for (uint256 p = 0; p < cdpPools.length; p++) {
            PoolContracts memory c = _getPoolContracts(cdpPools[p]);
            string memory idx = vm.toString(p);

            address victim = makeAddr(string.concat("gainVictim_", idx));
            (uint256 victimTroveId,,) = _openTroveAtCR(victim, c, 115);

            address depositor = makeAddr(string.concat("gainDepositor_", idx));
            _openTroveAndDepositToSP(depositor, c);

            uint256 gainBefore = IStabilityPool(c.stabilityPool).getDepositorCollGain(depositor);

            _mockLowerPrice(c, 75);
            _liquidateTrove(c, victimTroveId);
            vm.clearMockedCalls();

            uint256 gainAfter = IStabilityPool(c.stabilityPool).getDepositorCollGain(depositor);
            assertGt(gainAfter, gainBefore, string.concat("SP depositor should have coll gains for pool ", idx));

            // Claim gains via withdrawFromSP(0, doClaim=true) since user still has an active deposit
            uint256 collBefore = IERC20(c.collToken).balanceOf(depositor);
            vm.prank(depositor);
            IStabilityPool(c.stabilityPool).withdrawFromSP(0, true);
            uint256 collAfter = IERC20(c.collToken).balanceOf(depositor);
            assertGt(
                collAfter, collBefore, string.concat("Depositor should receive coll after claiming for pool ", idx)
            );
        }
    }

    // ========== Internal Helpers ==========

    /// @dev Get key contract addresses for a CDP pool via AddressesRegistry lookup
    function _getPoolContracts(address pool) internal view returns (PoolContracts memory c) {
        IAddressesRegistry ar = _getAddressesRegistry(pool);
        c.borrowerOps = address(ar.borrowerOperations());
        c.troveManager = address(ar.troveManager());
        c.stabilityPool = address(ar.stabilityPool());
        c.priceFeed = address(ar.priceFeed());
        c.collToken = address(ar.collToken());
        c.gasToken = address(ar.gasToken());
        c.debtToken = _getDebtToken(pool);
    }

    /// @dev Calculate collateral amount for a given debt, price, target CR, and token decimals
    function _calculateCollateral(uint256 debtAmount, uint256 price, uint256 targetCR, uint8 decimals)
        internal
        pure
        returns (uint256)
    {
        uint256 collAmount = (debtAmount * targetCR) / price;
        if (decimals < 18) {
            collAmount = collAmount / (10 ** (18 - decimals));
        }
        collAmount = collAmount + (collAmount / 100); // +1% buffer
        return collAmount;
    }

    /// @dev Holds parameters for opening a trove
    struct OpenTroveParams {
        uint256 debtAmount;
        uint256 collAmount;
        uint256 interestRate;
        uint256 ethGasComp;
    }

    /// @dev Opens a trove for a user and returns (troveId, debtAmount, collAmount)
    function _openTroveForUser(address user, PoolContracts memory c)
        internal
        returns (uint256 troveId, uint256 debtAmount, uint256 collAmount)
    {
        OpenTroveParams memory p = _buildTroveParams(c);
        debtAmount = p.debtAmount;
        collAmount = p.collAmount;

        _dealTokens(c.collToken, user, p.collAmount);
        _dealTokens(c.gasToken, user, p.ethGasComp);

        vm.startPrank(user);
        IERC20(c.collToken).approve(c.borrowerOps, p.collAmount);
        IERC20(c.gasToken).approve(c.borrowerOps, p.ethGasComp);
        troveId = _callOpenTrove(c.borrowerOps, user, p);
        vm.stopPrank();
    }

    /// @dev Build trove parameters from on-chain state
    function _buildTroveParams(PoolContracts memory c) internal returns (OpenTroveParams memory p) {
        ISystemParams sysParams = IStabilityPool(c.stabilityPool).systemParams();
        uint256 price = IPriceFeed(c.priceFeed).fetchPrice();
        uint256 mcr = IBorrowerOperations(c.borrowerOps).MCR();
        uint8 decimals = IERC20Metadata(c.collToken).decimals();

        p.debtAmount = sysParams.MIN_DEBT() + 100e18;
        p.collAmount = _calculateCollateral(p.debtAmount, price, mcr * 2, decimals);
        p.interestRate = sysParams.MIN_ANNUAL_INTEREST_RATE() + 1e16;
        p.ethGasComp = sysParams.ETH_GAS_COMPENSATION();
    }

    /// @dev Call IBorrowerOperations.openTrove with params struct to avoid stack-too-deep
    function _callOpenTrove(address borrowerOps, address user, OpenTroveParams memory p) internal returns (uint256) {
        return IBorrowerOperations(borrowerOps)
            .openTrove(
                user,
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
    }

    /// @dev Opens a trove at a specific CR multiplier percent over MCR (e.g., 115 = MCR * 1.15)
    function _openTroveAtCR(address user, PoolContracts memory c, uint256 crMultiplierPct)
        internal
        returns (uint256 troveId, uint256 debtAmount, uint256 collAmount)
    {
        OpenTroveParams memory p = _buildTroveParamsAtCR(c, crMultiplierPct);
        debtAmount = p.debtAmount;
        collAmount = p.collAmount;

        _dealTokens(c.collToken, user, p.collAmount);
        _dealTokens(c.gasToken, user, p.ethGasComp);

        vm.startPrank(user);
        IERC20(c.collToken).approve(c.borrowerOps, p.collAmount);
        IERC20(c.gasToken).approve(c.borrowerOps, p.ethGasComp);
        troveId = _callOpenTrove(c.borrowerOps, user, p);
        vm.stopPrank();
    }

    /// @dev Build trove parameters with custom CR multiplier percent over MCR
    function _buildTroveParamsAtCR(PoolContracts memory c, uint256 crMultiplierPct)
        internal
        returns (OpenTroveParams memory p)
    {
        ISystemParams sysParams = IStabilityPool(c.stabilityPool).systemParams();
        uint256 price = IPriceFeed(c.priceFeed).fetchPrice();
        uint256 mcr = IBorrowerOperations(c.borrowerOps).MCR();
        uint8 decimals = IERC20Metadata(c.collToken).decimals();

        p.debtAmount = sysParams.MIN_DEBT() + 100e18;
        p.collAmount = _calculateCollateral(p.debtAmount, price, (mcr * crMultiplierPct) / 100, decimals);
        p.interestRate = sysParams.MIN_ANNUAL_INTEREST_RATE() + 1e16;
        p.ethGasComp = sysParams.ETH_GAS_COMPENSATION();
    }

    /// @dev Open a trove for user and deposit all debt tokens into StabilityPool
    function _openTroveAndDepositToSP(address user, PoolContracts memory c) internal returns (uint256 depositAmount) {
        (, uint256 debtAmount,) = _openTroveForUser(user, c);
        depositAmount = debtAmount;
        vm.startPrank(user);
        IERC20(c.debtToken).approve(c.stabilityPool, debtAmount);
        IStabilityPool(c.stabilityPool).provideToSP(debtAmount, false);
        vm.stopPrank();
    }

    /// @dev Mock the price feed to return price at a percentage of current (e.g., 75 = 75% of current)
    function _mockLowerPrice(PoolContracts memory c, uint256 pricePct) internal returns (uint256 droppedPrice) {
        address priceFeedAddr = c.priceFeed;
        uint256 currentPrice = IPriceFeed(priceFeedAddr).fetchPrice();
        droppedPrice = (currentPrice * pricePct) / 100;
        vm.mockCall(priceFeedAddr, abi.encodeWithSelector(IPriceFeed.fetchPrice.selector), abi.encode(droppedPrice));
    }

    /// @dev Liquidate a single trove via batchLiquidateTroves
    function _liquidateTrove(PoolContracts memory c, uint256 troveId) internal {
        uint256[] memory troveIds = new uint256[](1);
        troveIds[0] = troveId;
        ITroveManager(c.troveManager).batchLiquidateTroves(troveIds);
    }
}
