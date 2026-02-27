// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IActivePool} from "lib/bold/contracts/src/Interfaces/IActivePool.sol";
import {IAddressesRegistry} from "lib/bold/contracts/src/Interfaces/IAddressesRegistry.sol";
import {IBorrowerOperations} from "lib/bold/contracts/src/Interfaces/IBorrowerOperations.sol";
import {IPriceFeed} from "lib/bold/contracts/src/Interfaces/IPriceFeed.sol";
import {IStabilityPool} from "lib/bold/contracts/src/Interfaces/IStabilityPool.sol";
import {IStableTokenV3} from "lib/bold/contracts/src/Interfaces/IStableTokenV3.sol";
import {ISystemParams} from "lib/bold/contracts/src/Interfaces/ISystemParams.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/bold/contracts/src/Types/TroveChange.sol";

/**
 * @title ReserveTroveFactory
 * @notice Factory contract that creates a Liquity V2 trove to back an existing debt token supply.
 */
contract ReserveTroveFactory is Ownable {
    /* ============================================================ */
    /* ==================== Constants ============================= */
    /* ============================================================ */

    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant UPFRONT_INTEREST_PERIOD = 7 days;
    uint256 public constant ONE_YEAR = 365 days;

    /* ============================================================ */
    /* ==================== State Variables ======================== */
    /* ============================================================ */

    /// @notice The address that will own the trove NFT
    address public reserveTroveManager;

    /* ============================================================ */
    /* ======================== Events ============================ */
    /* ============================================================ */

    /**
     * @notice Emitted when a reserve trove is successfully created
     * @param addressesRegistry The Liquity V2 addresses registry used
     * @param troveId The ID of the newly created trove
     * @param debtAmount The amount of debt tokens backed by the trove
     * @param collateralAmount The amount of collateral deposited into the trove
     */
    event ReserveTroveCreated(
        address indexed addressesRegistry,
        uint256 indexed troveId,
        uint256 debtAmount,
        uint256 collateralAmount
    );

    /* ============================================================ */
    /* ======================= Constructor ======================== */
    /* ============================================================ */

    /**
     * @notice Initializes the factory with the trove manager address and owner
     * @param _reserveTroveManager The address that will own the trove NFT
     * @param _initialOwner The address that will be set as the Ownable owner
     */
    constructor(address _reserveTroveManager, address _initialOwner) {
        require(_reserveTroveManager != address(0), "Invalid reserve trove manager");
        require(_initialOwner != address(0), "Invalid initial owner");
        reserveTroveManager = _reserveTroveManager;
        transferOwnership(_initialOwner);

    }

    receive() external payable {}

    /* ============================================================ */
    /* ==================== External Functions ==================== */
    /* ============================================================ */

    /**
     * @notice Creates a Liquity V2 trove that backs the existing debt token supply
     * @dev Mints collateral tokens, opens a trove via BorrowerOperations, and burns
     *      the borrowed debt tokens. Requires this contract to have:
     *      - Minter role on the collateral token
     *      - Burner role on the debt token
     *      - Sufficient gas token balance for ETH_GAS_COMPENSATION
     * @param _addressesRegistry The Liquity V2 addresses registry for this liquity deployment
     * @param collateralizationRatio Target ICR for the trove
     * @param interestRate Annual interest rate for the trove
     * @return troveId The ID of the newly created trove
     */
    function createReserveTrove(
        IAddressesRegistry _addressesRegistry,
        uint256 collateralizationRatio,
        uint256 interestRate
    ) external onlyOwner returns (uint256 troveId) {
        ISystemParams systemParams = _addressesRegistry.stabilityPool().systemParams();
        _validateInputs(_addressesRegistry, systemParams, collateralizationRatio);

        IStableTokenV3 debtToken = IStableTokenV3(address(_addressesRegistry.boldToken()));
        uint256 debtAmount = debtToken.totalSupply();
        require(debtAmount > 0, "No existing debt to back");

        uint256 collateralNeeded = _mintCollateralAndApprove(
            _addressesRegistry,
            collateralizationRatio,
            interestRate,
            debtAmount
        );

        troveId = _addressesRegistry.borrowerOperations().openTrove(
            reserveTroveManager,
            0, // ownerIndex
            collateralNeeded,
            debtAmount,
            0, // upperHint
            0, // lowerHint
            interestRate,
            type(uint256).max, // maxUpfrontFee
            address(0), // addManager
            address(0), // removeManager
            address(0) // receiver
        );

        // Burn the borrowed debt tokens to back the existing supply
        debtToken.burn(debtAmount);

        emit ReserveTroveCreated(address(_addressesRegistry), troveId, debtAmount, collateralNeeded);
    }

    /**
     * @notice Withdraws any ERC20 tokens held by this contract
     * @dev Used to recover leftover tokens after trove creation (e.g. excess collateral)
     * @param _token The token to withdraw
     * @param _recipient The address to send the token to
     */
    function withdraw(IERC20 _token, address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        _token.transfer(_recipient, balance);
    }

    /* ============================================================ */
    /* ==================== Internal Functions ==================== */
    /* ============================================================ */

    /**
     * @notice Validates that the factory has the required permissions and parameters
     * @param _addressesRegistry The Liquity V2 addresses registry
     * @param _systemParams The system params contract for reading protocol constants
     * @param collateralizationRatio The target collateralization ratio to validate
     */
    function _validateInputs(
        IAddressesRegistry _addressesRegistry,
        ISystemParams _systemParams,
        uint256 collateralizationRatio
    ) internal view {
        require(
            IStableTokenV3(address(_addressesRegistry.collToken())).isMinter(address(this)),
            "Not a minter on collateral token"
        );
        require(
            IStableTokenV3(address(_addressesRegistry.boldToken())).isBurner(address(this)),
            "Not a burner on debt token"
        );
        require(collateralizationRatio > _systemParams.CCR(), "CR must be greater than CCR");

        uint256 gasCompensation = _systemParams.ETH_GAS_COMPENSATION();
        require(
            IERC20(address(_addressesRegistry.gasToken())).balanceOf(address(this)) >= gasCompensation,
            "Insufficient gas token for compensation"
        );
    }

    /**
     * @notice Calculates collateral needed, mints it, and approves BorrowerOperations
     * @dev Approves both collateral and gas token transfers to BorrowerOperations
     * @param _addressesRegistry The Liquity V2 addresses registry
     * @param collateralizationRatio The target collateralization ratio
     * @param interestRate The annual interest rate
     * @param debtAmount The total debt supply to back
     * @return collateralNeeded The amount of collateral minted and approved
     */
    function _mintCollateralAndApprove(
        IAddressesRegistry _addressesRegistry,
        uint256 collateralizationRatio,
        uint256 interestRate,
        uint256 debtAmount
    ) internal returns (uint256 collateralNeeded) {
        uint256 price = IPriceFeed(_addressesRegistry.priceFeed()).fetchPrice();
        collateralNeeded = _calculateCollateralNeeded(
            collateralizationRatio,
            debtAmount,
            interestRate,
            price,
            _addressesRegistry.activePool()
        );

        IStableTokenV3 collateralToken = IStableTokenV3(address(_addressesRegistry.collToken()));
        address borrowerOps = address(_addressesRegistry.borrowerOperations());

        collateralToken.mint(address(this), collateralNeeded);
        collateralToken.approve(borrowerOps, collateralNeeded);
        uint256 gasCompensation = _addressesRegistry.stabilityPool().systemParams().ETH_GAS_COMPENSATION();
        IERC20(address(_addressesRegistry.gasToken())).approve(borrowerOps, gasCompensation);
    }

    /**
     * @notice Calculates collateral needed to achieve target CR, accounting for the upfront fee
     * @dev Formula: collateral = collateralizationRatio * (debtAmount + upfrontFee) / price
     *      Rounds up to ensure the trove always has sufficient collateral.
     * @param collateralizationRatio The target collateralization ratio (18 decimals)
     * @param debtAmount The amount of debt to back
     * @param interestRate The annual interest rate used to estimate the upfront fee
     * @param price The current oracle price of collateral in debt token units
     * @param activePool The active pool contract used to estimate the average interest rate
     * @return The amount of collateral tokens needed
     */
    function _calculateCollateralNeeded(
        uint256 collateralizationRatio,
        uint256 debtAmount,
        uint256 interestRate,
        uint256 price,
        IActivePool activePool
    ) internal view returns (uint256) {
        uint256 upfrontFee = _estimateUpfrontFee(activePool, debtAmount, interestRate);
        uint256 totalDebt = debtAmount + upfrontFee;

        // Round up to ensure we always have enough collateral
        return (collateralizationRatio * totalDebt + price - 1) / price;
    }

    /**
     * @notice Estimates the upfront fee using the same formula as BorrowerOperations
     * @dev Formula: fee = debtAmount * avgInterestRate * UPFRONT_INTEREST_PERIOD / ONE_YEAR / DECIMAL_PRECISION
     * @param _activePool The active pool contract for reading the current weighted average interest rate
     * @param _debtAmount The amount of debt being borrowed
     * @param _interestRate The interest rate of the new trove
     * @return The estimated upfront fee in debt token units
     */
    function _estimateUpfrontFee(
        IActivePool _activePool,
        uint256 _debtAmount,
        uint256 _interestRate
    ) internal view returns (uint256) {
        TroveChange memory change;
        change.debtIncrease = _debtAmount;
        change.newWeightedRecordedDebt = _debtAmount * _interestRate;

        uint256 avgInterestRate = _activePool.getNewApproxAvgInterestRateFromTroveChange(change);
        return (_debtAmount * avgInterestRate * UPFRONT_INTEREST_PERIOD) / (ONE_YEAR * DECIMAL_PRECISION);
    }
}
