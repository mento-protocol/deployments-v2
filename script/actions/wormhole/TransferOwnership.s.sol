// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NTTScriptBase} from "script/deploy/wormhole/NTTScriptBase.sol";
import {INttDeployHelper} from "./interfaces/INttDeployHelper.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IPausable} from "./interfaces/IPausable.sol";

// ── Script ──────────────────────────────────────────────────────────────────

/// @title TransferOwnership
/// @notice Governance action to transfer NTT contract ownership and pauser
///         capability to a new address (resolved via addressbook label).
///
/// @dev Transfers ownership of NttManager (which cascades to all registered
///      transceivers) and separately transfers pauser capability on both
///      NttManager and WormholeTransceiver (pauser does NOT cascade).
///
///      Usage:
///        treb run TransferOwnership -e token=USDm -e NEW_OWNER_LABEL=GovernanceMultisig --network celo
///        treb run TransferOwnership -e token=GBPm -e NEW_OWNER_LABEL=GovernanceMultisig --network monad
contract TransferOwnership is NTTScriptBase {
    using Senders for Senders.Sender;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    address internal localNttManager;
    address internal localTransceiver;
    address internal newOwner;
    string internal chainName;

    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        string memory newOwnerLabel = vm.envString("NEW_OWNER_LABEL");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory myChain = _findMyChain(config);
        chainName = myChain.chainName;

        // Resolve local NTT contracts from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "TransferOwnership: local NttDeployHelper not found in registry");
        localNttManager = INttDeployHelper(localHelper).nttManagerProxy();
        localTransceiver = INttDeployHelper(localHelper).transceiverProxy();

        // Resolve new owner
        newOwner = lookup(newOwnerLabel);
        require(
            newOwner != address(0), string.concat("TransferOwnership: '", newOwnerLabel, "' not found in addressbook")
        );

        console.log("=== TransferOwnership: %s on %s ===", tokenName, chainName);
        console.log("  NttManager:   %s", localNttManager);
        console.log("  Transceiver:  %s", localTransceiver);
        console.log("  New owner:    %s", newOwner);
        console.log("");
    }

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    /// @custom:env {string} NEW_OWNER_LABEL - Addressbook label for the new owner (e.g. "GovernanceMultisig")
    /// @custom:senders migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        // 1. Transfer NttManager ownership (cascades to all registered transceivers)
        address currentOwner = IOwnable(localNttManager).owner();
        if (currentOwner != newOwner) {
            console.log("  > Transferring NttManager ownership to %s...", newOwner);
            IOwnable(owner.harness(localNttManager)).transferOwnership(newOwner);
        } else {
            console.log("  > NttManager already owned by target, skipping");
        }

        // 2. Transfer NttManager pauser capability (does NOT cascade)
        address currentManagerPauser = IPausable(localNttManager).pauser();
        if (currentManagerPauser != newOwner) {
            console.log("  > Transferring NttManager pauser to %s...", newOwner);
            IPausable(owner.harness(localNttManager)).transferPauserCapability(newOwner);
        } else {
            console.log("  > NttManager pauser already correct, skipping");
        }

        // 3. Transfer WormholeTransceiver pauser capability (does NOT cascade)
        address currentXceiverPauser = IPausable(localTransceiver).pauser();
        if (currentXceiverPauser != newOwner) {
            console.log("  > Transferring Transceiver pauser to %s...", newOwner);
            IPausable(owner.harness(localTransceiver)).transferPauserCapability(newOwner);
        } else {
            console.log("  > Transceiver pauser already correct, skipping");
        }

        console.log("");
        console.log("=== TransferOwnership: %s complete ===", tokenName);
    }
}
