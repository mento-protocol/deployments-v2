// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IMentoConfig} from "../config/IMentoConfig.sol";
import {Anvil} from "./Anvil.sol";

/// @title OracleHelper
/// @notice Re-reports current oracle rates so they remain fresh on forked state.
library OracleHelper {
    address private constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    /// @notice Re-reports all configured rate feeds using vm.prank (simulation fork only).
    function refreshOracleRates(address sortedOracles, IMentoConfig config) internal {
        ISortedOracles so = ISortedOracles(sortedOracles);
        address[] memory rateFeedIDs = _collectRateFeedIDs(config);

        for (uint256 i = 0; i < rateFeedIDs.length; i++) {
            address rateFeedID = rateFeedIDs[i];
            (uint256 rate,) = so.medianRate(rateFeedID);
            if (rate == 0) continue;

            address[] memory oracles = so.getOracles(rateFeedID);
            if (oracles.length == 0) continue;

            vm.prank(oracles[0]);
            so.report(rateFeedID, rate, address(0), address(0));
        }
    }

    /// @notice Re-reports stale rate feeds on the Anvil node via RPC
    ///         impersonation so that rates persist for the execution fork.
    ///         Feeds whose report is still within half its expiry window are
    ///         skipped to avoid unnecessary RPC calls: they're fresh enough to
    ///         stay valid through the execution phase without re-reporting.
    ///
    ///         Gotcha: this also happens to sidestep a nonce bug for EUROP/EUR.
    ///         Its oracle is the migrationOwner, which is also a treb broadcast
    ///         sender. Impersonating it here to re-report sends a real tx that
    ///         bumps the sender's on-chain nonce outside treb's tracking,
    ///         desyncing it and breaking the broadcast with "nonce too low".
    ///         The freshness skip dodges this because EUROP/EUR has a very long
    ///         (~1 year) expiry, so it's always within its half-window and never
    ///         re-reported here. If a sender-oracle feed ever had a short expiry,
    ///         this skip would not protect it and the nonce bug would resurface.
    function refreshOracleRatesAnvil(address sortedOracles, IMentoConfig config) internal {
        ISortedOracles so = ISortedOracles(sortedOracles);
        address[] memory rateFeedIDs = _collectRateFeedIDs(config);

        for (uint256 i = 0; i < rateFeedIDs.length; i++) {
            address rateFeedID = rateFeedIDs[i];
            (uint256 rate,) = so.medianRate(rateFeedID);
            if (rate == 0) continue;

            uint256 expiry = so.getTokenReportExpirySeconds(rateFeedID);
            uint256 reportTs = so.medianTimestamp(rateFeedID);
            if (reportTs + expiry / 2 > block.timestamp) continue;

            address[] memory oracles = so.getOracles(rateFeedID);
            if (oracles.length == 0) continue;

            Anvil.setBalanceRpc(oracles[0], 1 ether);
            Anvil.sendTransactionAs(
                oracles[0], sortedOracles, abi.encodeCall(so.report, (rateFeedID, rate, address(0), address(0)))
            );
        }
    }

    /// @notice Re-reports all configured rate feeds only when TREB_FORK_MODE=true.
    ///         Refreshes on both the simulation fork (vm.prank) and the Anvil
    ///         node (RPC impersonation) so rates are fresh for both phases.
    ///         No-op on live deployments.
    ///         The Anvil refresh runs first: the vm.prank refresh updates
    ///         medianTimestamp in simulation state, which would make every feed
    ///         look fresh to the Anvil refresh's staleness check.
    function refreshOracleRatesIfFork(address sortedOracles, IMentoConfig config) internal {
        if (!vm.envOr("TREB_FORK_MODE", false)) return;
        refreshOracleRatesAnvil(sortedOracles, config);
        refreshOracleRates(sortedOracles, config);
    }

    /// @dev Collects unique rate feed IDs from both getRateFeeds() and getFPMMConfigs().
    function _collectRateFeedIDs(IMentoConfig config) private view returns (address[] memory) {
        IMentoConfig.RateFeed[] memory rateFeeds = config.getRateFeeds();
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        // Allocate max possible size, then trim
        address[] memory all = new address[](rateFeeds.length + fpmmConfigs.length);
        uint256 count = 0;

        for (uint256 i = 0; i < rateFeeds.length; i++) {
            all[count++] = rateFeeds[i].rateFeedId;
        }

        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            address id = fpmmConfigs[i].referenceRateFeedID;
            bool duplicate = false;
            for (uint256 j = 0; j < count; j++) {
                if (all[j] == id) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                all[count++] = id;
            }
        }

        // Trim to actual size
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = all[i];
        }
        return result;
    }
}
