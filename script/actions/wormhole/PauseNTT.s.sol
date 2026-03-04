// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NttDeployHelper} from "script/deploy/wormhole/NttDeployHelper.sol";
import {INTTPausable} from "./interfaces/INTTPausable.sol";

// ── Script ──────────────────────────────────────────────────────────────────

/// @title PauseNTT
/// @notice Governance action to pause or unpause the NTT bridge in emergencies.
///
/// @dev pause() can be called by owner or pauser role, but unpause() requires
///      owner. This script uses the owner sender to support both operations.
///
///      Usage:
///        NTT_TOKEN=USDm PAUSE=true  treb run PauseNTT --network celo
///        NTT_TOKEN=USDm PAUSE=false treb run PauseNTT --network celo
contract PauseNTT is TrebScript {
    using Senders for Senders.Sender;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    address internal localNttManager;
    string internal chainName;
    bool internal shouldPause;

    function setUp() public {
        // Load config
        tokenName = vm.envString("NTT_TOKEN");
        shouldPause = vm.envBool("PAUSE");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory myChain = _findMyChain(config);
        chainName = myChain.chainName;

        // Resolve local NttManager from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "PauseNTT: local NttDeployHelper not found in registry");
        localNttManager = NttDeployHelper(localHelper).nttManagerProxy();

        console.log("=== PauseNTT: %s on %s ===", tokenName, chainName);
        console.log("  NttManager: %s", localNttManager);
        console.log("  Action:     %s", shouldPause ? "PAUSE" : "UNPAUSE");
        console.log("");
    }

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

    // ── Config helpers ──────────────────────────────────────────────────

    function _loadConfig(string memory _tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(_tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(_tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("PauseNTT: unknown NTT_TOKEN: ", _tokenName));
        }
    }

    function _findMyChain(NTTTokenConfig memory config) internal view returns (NTTChainConfig memory) {
        uint256 cid;
        assembly {
            cid := chainid()
        }
        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].evmChainId == cid) return config.chains[i];
        }
        revert(string.concat("PauseNTT: current chain (", vm.toString(cid), ") not in config for ", config.tokenName));
    }
}
