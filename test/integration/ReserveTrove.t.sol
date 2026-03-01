// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {LatestTroveData} from "bold/src/Types/LatestTroveData.sol";

/**
 * @title ReserveTrove
 * @notice Verifies reserve troves are healthy: active with correct collateral and debt,
 *         collateralization meets MCR, and interest accrues over time.
 */
contract ReserveTrove is V3IntegrationBase {
    address[] internal cdpPools;

    function setUp() public override {
        super.setUp();
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
    }

    // ========== Reserve Trove Active with Non-Zero Values ==========

    /// @notice Verify reserve trove is active for each CDP pool
    function test_reserveTrove_isActive() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            ITroveManager.Status status = ITroveManager(troveManagerAddr).getTroveStatus(troveId);
            assertEq(
                uint256(status),
                uint256(ITroveManager.Status.active),
                string.concat("Reserve trove is not active for CDP pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify reserve trove has non-zero collateral
    function test_reserveTrove_hasNonZeroCollateral() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            LatestTroveData memory data = ITroveManager(troveManagerAddr).getLatestTroveData(troveId);
            assertGt(
                data.entireColl,
                0,
                string.concat("Reserve trove has zero collateral for CDP pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify reserve trove has non-zero debt
    function test_reserveTrove_hasNonZeroDebt() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            LatestTroveData memory data = ITroveManager(troveManagerAddr).getLatestTroveData(troveId);
            assertGt(
                data.entireDebt,
                0,
                string.concat("Reserve trove has zero debt for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Collateralization Ratio Meets MCR ==========

    /// @notice Verify reserve trove collateralization ratio is above the minimum (MCR)
    function test_reserveTrove_collateralizationAboveMCR() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (address borrowerOpsAddr,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            uint256 price = IPriceFeed(_getPriceFeed(troveManagerAddr)).fetchPrice();

            uint256 icr = ITroveManager(troveManagerAddr).getCurrentICR(troveId, price);
            uint256 mcr = IBorrowerOperations(borrowerOpsAddr).MCR();

            assertGe(
                icr,
                mcr,
                string.concat(
                    "Reserve trove ICR below MCR for CDP pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== Interest Accrual ==========

    /// @notice Verify interest accrues on the reserve trove over 30 days
    function test_reserveTrove_interestAccrual() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            // Record debt before time warp
            LatestTroveData memory dataBefore = ITroveManager(troveManagerAddr).getLatestTroveData(troveId);
            uint256 debtBefore = dataBefore.entireDebt;

            // Warp forward 30 days
            vm.warp(block.timestamp + 30 days);

            // Record debt after time warp
            LatestTroveData memory dataAfter = ITroveManager(troveManagerAddr).getLatestTroveData(troveId);
            uint256 debtAfter = dataAfter.entireDebt;

            assertGt(
                debtAfter,
                debtBefore,
                string.concat(
                    "Reserve trove debt did not increase after 30 days for CDP pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

}
