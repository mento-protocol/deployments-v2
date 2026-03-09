// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NTTScriptBase} from "script/deploy/wormhole/NTTScriptBase.sol";
import {INttDeployHelper} from "./interfaces/INttDeployHelper.sol";
import {INTTPausable} from "./interfaces/INTTPausable.sol";

// ── Script ──────────────────────────────────────────────────────────────────

/// @title PauseNTT
/// @notice Governance action to pause or unpause the NTT bridge in emergencies.
///
/// @dev pause() can be called by owner or pauser role, but unpause() requires
///      owner. This script uses the owner sender to support both operations.
///
///      Usage:
///        treb run PauseNTT -e token=USDm -e PAUSE=true --network celo
///        treb run PauseNTT -e token=USDm -e PAUSE=false --network celo
contract PauseNTT is NTTScriptBase {
    using Senders for Senders.Sender;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    address internal localNttManager;
    string internal chainName;
    bool internal shouldPause;

    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        shouldPause = vm.envBool("PAUSE");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory myChain = _findMyChain(config);
        chainName = myChain.chainName;

        // Resolve local NttManager from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "PauseNTT: local NttDeployHelper not found in registry");
        localNttManager = INttDeployHelper(localHelper).nttManagerProxy();

        console.log("=== PauseNTT: %s on %s ===", tokenName, chainName);
        console.log("  NttManager: %s", localNttManager);
        console.log("  Action:     %s", shouldPause ? "PAUSE" : "UNPAUSE");
        console.log("");
    }

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    /// @custom:env {bool} PAUSE - true to pause, false to unpause
    /// @custom:senders owner
    function run() public broadcast {
        Senders.Sender storage ownerSender = sender("owner");

        bool currentlyPaused = INTTPausable(localNttManager).isPaused();

        if (shouldPause) {
            if (!currentlyPaused) {
                console.log("  > Pausing NttManager...");
                INTTPausable(ownerSender.harness(localNttManager)).pause();
            } else {
                console.log("  > NttManager already paused, skipping");
            }
        } else {
            if (currentlyPaused) {
                console.log("  > Unpausing NttManager...");
                INTTPausable(ownerSender.harness(localNttManager)).unpause();
            } else {
                console.log("  > NttManager already unpaused, skipping");
            }
        }

        console.log("");
        console.log("=== PauseNTT: %s complete ===", tokenName);
    }
}
