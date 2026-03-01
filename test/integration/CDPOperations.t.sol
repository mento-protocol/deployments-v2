// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {ISystemParams} from "bold/src/Interfaces/ISystemParams.sol";
import {LatestTroveData} from "bold/src/Types/LatestTroveData.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev Minimal interface to read public state variables from StabilityPool not in IStabilityPool
interface IStabilityPoolReader {
    function collToken() external view returns (IERC20);
}

/**
 * @title CDPOperations
 * @notice Tests CDP user operations: opening troves, StabilityPool deposits and withdrawals.
 */
contract CDPOperations is V3IntegrationBase {
    address[] internal cdpPools;

    /// @dev Holds resolved contract addresses for a CDP pool
    struct PoolContracts {
        address borrowerOps;
        address troveManager;
        address stabilityPool;
        address collToken;
        address debtToken;
    }

    function setUp() public override {
        super.setUp();
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
    }

    // ========== Open Trove ==========

    /// @notice Test opening a new trove: deal collateral, approve, openTrove, verify active + debt tokens received
    function test_openTrove_successful() public {
        require(cdpPools.length > 0, "No CDP pools");
        PoolContracts memory c = _getPoolContracts(cdpPools[0]);

        address user = makeAddr("troveOpener");
        uint256 debtBefore = IERC20(c.debtToken).balanceOf(user);

        (uint256 troveId, uint256 debtAmount, uint256 collAmount) = _openTroveForUser(user, c);

        // Verify trove is active
        ITroveManager.Status status = ITroveManager(c.troveManager).getTroveStatus(troveId);
        assertEq(uint256(status), uint256(ITroveManager.Status.active), "Newly opened trove should be active");

        // Verify user received debt tokens
        uint256 debtAfter = IERC20(c.debtToken).balanceOf(user);
        assertGt(debtAfter, debtBefore, "User should have received debt tokens after opening trove");
        assertEq(debtAfter - debtBefore, debtAmount, "User should have received exactly debtAmount");

        // Verify trove has correct collateral
        LatestTroveData memory data = ITroveManager(c.troveManager).getLatestTroveData(troveId);
        assertEq(data.entireColl, collAmount, "Trove collateral should match deposited amount");
    }

    // ========== StabilityPool Deposit ==========

    /// @notice Test depositing debt tokens into StabilityPool
    function test_stabilityPool_deposit() public {
        require(cdpPools.length > 0, "No CDP pools");
        PoolContracts memory c = _getPoolContracts(cdpPools[0]);

        address user = makeAddr("spDepositor");
        (,uint256 debtAmount,) = _openTroveForUser(user, c);

        uint256 depositAmount = debtAmount / 2;
        uint256 depositBefore = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
        uint256 balanceBefore = IERC20(c.debtToken).balanceOf(user);

        vm.startPrank(user);
        IERC20(c.debtToken).approve(c.stabilityPool, depositAmount);
        IStabilityPool(c.stabilityPool).provideToSP(depositAmount, false);
        vm.stopPrank();

        // Verify deposit registered
        uint256 depositAfter = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
        assertGt(depositAfter, depositBefore, "SP deposit should be registered");
        assertEq(depositAfter - depositBefore, depositAmount, "SP deposit should match deposited amount");

        // Verify tokens were transferred from user
        uint256 balanceAfter = IERC20(c.debtToken).balanceOf(user);
        assertEq(balanceBefore - balanceAfter, depositAmount, "Debt tokens should be transferred to SP");
    }

    // ========== StabilityPool Withdrawal ==========

    /// @notice Test withdrawing from StabilityPool
    function test_stabilityPool_withdrawal() public {
        require(cdpPools.length > 0, "No CDP pools");
        PoolContracts memory c = _getPoolContracts(cdpPools[0]);

        address user = makeAddr("spWithdrawer");
        (,uint256 debtAmount,) = _openTroveForUser(user, c);

        // Deposit into SP
        uint256 depositAmount = debtAmount / 2;
        vm.startPrank(user);
        IERC20(c.debtToken).approve(c.stabilityPool, depositAmount);
        IStabilityPool(c.stabilityPool).provideToSP(depositAmount, false);
        vm.stopPrank();

        // Record state before withdrawal
        uint256 depositBefore = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
        uint256 balanceBefore = IERC20(c.debtToken).balanceOf(user);

        // Withdraw from SP
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(user);
        IStabilityPool(c.stabilityPool).withdrawFromSP(withdrawAmount, false);

        // Verify withdrawal
        uint256 depositAfter = IStabilityPool(c.stabilityPool).getCompoundedBoldDeposit(user);
        uint256 balanceAfter = IERC20(c.debtToken).balanceOf(user);

        assertLt(depositAfter, depositBefore, "SP deposit should decrease after withdrawal");
        assertGt(balanceAfter, balanceBefore, "User balance should increase after SP withdrawal");
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Withdrawn amount should match requested");
    }

    // ========== Internal Helpers ==========

    /// @dev Get key contract addresses for a CDP pool
    function _getPoolContracts(address pool) internal view returns (PoolContracts memory c) {
        ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
            ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(pool);

        c.stabilityPool = cdpConfig.stabilityPool;
        ITroveManager tm = IStabilityPool(c.stabilityPool).troveManager();
        c.troveManager = address(tm);
        c.borrowerOps = address(tm.borrowerOperations());
        c.collToken = address(IStabilityPoolReader(c.stabilityPool).collToken());
        c.debtToken = _getDebtToken(pool);
    }

    /// @dev Returns the debt token for a CDP pool based on the isToken0Debt flag
    function _getDebtToken(address pool) internal view returns (address) {
        (bool success, bytes memory data) = cdpLiquidityStrategy.staticcall(
            abi.encodeWithSignature("poolConfigs(address)", pool)
        );
        require(success, "Failed to read poolConfigs");
        bool isToken0Debt = abi.decode(data, (bool));
        return isToken0Debt ? IFPMM(pool).token0() : IFPMM(pool).token1();
    }

    /// @dev Read the priceFeed address from TroveManager storage slot 2
    function _getPriceFeed(address troveManagerAddr) internal view returns (address) {
        return address(uint160(uint256(vm.load(troveManagerAddr, bytes32(uint256(2))))));
    }

    /// @dev Calculate collateral amount for a given debt, price, target CR, and token decimals
    function _calculateCollateral(
        uint256 debtAmount,
        uint256 price,
        uint256 targetCR,
        uint8 decimals
    ) internal pure returns (uint256) {
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

        deal(c.collToken, user, p.collAmount + p.ethGasComp);

        vm.startPrank(user);
        IERC20(c.collToken).approve(c.borrowerOps, p.collAmount + p.ethGasComp);
        troveId = _callOpenTrove(c.borrowerOps, user, p);
        vm.stopPrank();
    }

    /// @dev Build trove parameters from on-chain state
    function _buildTroveParams(PoolContracts memory c) internal returns (OpenTroveParams memory p) {
        ISystemParams sysParams = IStabilityPool(c.stabilityPool).systemParams();
        uint256 price = IPriceFeed(_getPriceFeed(c.troveManager)).fetchPrice();
        uint256 mcr = IBorrowerOperations(c.borrowerOps).MCR();
        uint8 decimals = IERC20Metadata(c.collToken).decimals();

        p.debtAmount = sysParams.MIN_DEBT() + 100e18;
        p.collAmount = _calculateCollateral(p.debtAmount, price, mcr * 2, decimals);
        p.interestRate = sysParams.MIN_ANNUAL_INTEREST_RATE() + 1e16;
        p.ethGasComp = sysParams.ETH_GAS_COMPENSATION();
    }

    /// @dev Call IBorrowerOperations.openTrove with params struct to avoid stack-too-deep
    function _callOpenTrove(address borrowerOps, address user, OpenTroveParams memory p)
        internal
        returns (uint256)
    {
        return IBorrowerOperations(borrowerOps).openTrove(
            user, 0, p.collAmount, p.debtAmount, 0, 0,
            p.interestRate, p.debtAmount, address(0), address(0), address(0)
        );
    }
}
