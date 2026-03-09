// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/// @title TriggerRebalance
/// @notice Triggers rebalance for all eligible FPMM pools across both
///         ReserveLiquidityStrategy and CDPLiquidityStrategy.
contract TriggerRebalance is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address rlsAddr = lookupProxyOrFail("ReserveLiquidityStrategy");
        address cdpAddr = lookupProxyOrFail("CDPLiquidityStrategy");

        console.log("=== ReserveLiquidityStrategy ===");
        _rebalancePools(deployer, ILiquidityStrategy(rlsAddr));

        console.log("");
        console.log("=== CDPLiquidityStrategy ===");
        _rebalancePools(deployer, ILiquidityStrategy(cdpAddr));
    }

    function _rebalancePools(Senders.Sender storage _sender, ILiquidityStrategy strategy) internal {
        address[] memory pools = strategy.getPools();
        console.log("  pools registered:", pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            string memory label = _poolLabel(pool);

            (,,,,, uint16 threshold, uint256 priceDiff) = IFPMM(pool).getRebalancingState();

            if (priceDiff <= uint256(threshold)) {
                console.log("  SKIP (within threshold):", label);
                continue;
            }

            // Use try/catch to handle cooldown or other reverts gracefully
            try ILiquidityStrategy(_sender.harness(address(strategy))).rebalance(pool) {
                console.log("  REBALANCED:", label);
            } catch (bytes memory reason) {
                console.log("  FAILED:", label);
                console.logBytes(reason);
            }
        }
    }

    function _poolLabel(address pool) internal view returns (string memory) {
        address t0 = IFPMM(pool).token0();
        address t1 = IFPMM(pool).token1();
        string memory s0 = IERC20Metadata(t0).symbol();
        string memory s1 = IERC20Metadata(t1).symbol();
        return string.concat(s0, "/", s1, " (", vm.toString(pool), ")");
    }
}
