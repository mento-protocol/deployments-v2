// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NttDeployHelper} from "script/deploy/wormhole/NttDeployHelper.sol";
import {ITransceiverUpgradeable} from "./interfaces/ITransceiverUpgradeable.sol";

// ── Script ────────────────────────────────────────────────────────────────

/// @title UpgradeWormholeTransceiver
/// @notice Governance action to upgrade the WormholeTransceiver implementation
///         without redeploying the proxy.
///
/// @dev Deploys a new WormholeTransceiver implementation via CREATE3 with a
///      versioned label, then calls upgrade() on the existing proxy. The new
///      implementation must be constructed with identical immutables (nttManager,
///      wormholeCoreBridge, consistencyLevel) so that _checkImmutables() passes
///      during the upgrade.
///
///      Usage:
///        token=USDm NTT_VERSION=v2 treb run UpgradeWormholeTransceiver --network celo
///        token=GBPm NTT_VERSION=v3 treb run UpgradeWormholeTransceiver --network monad
contract UpgradeWormholeTransceiver is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    // ── Constants ─────────────────────────────────────────────────────────
    /// @dev Consistency level for WormholeTransceiver (200 = instant finality).
    uint8 constant CONSISTENCY_LEVEL = 200;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    string internal version;
    address internal localTransceiverProxy;
    address internal localNttManagerProxy;
    address internal wormholeCoreBridge;

    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        version = vm.envString("NTT_VERSION");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory chainConfig = _findMyChain(config);

        // Resolve local proxy addresses from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "UpgradeWormholeTransceiver: local NttDeployHelper not found in registry");
        localTransceiverProxy = NttDeployHelper(localHelper).transceiverProxy();
        localNttManagerProxy = NttDeployHelper(localHelper).nttManagerProxy();

        // Resolve WormholeCoreBridge from addressbook
        wormholeCoreBridge = lookup("WormholeCoreBridge");

        console.log("=== UpgradeWormholeTransceiver: %s %s on %s ===", tokenName, version, chainConfig.chainName);
        console.log("  Transceiver proxy: %s", localTransceiverProxy);
        console.log("  NttManager proxy:  %s", localNttManagerProxy);
        console.log("  WormholeCoreBridge: %s", wormholeCoreBridge);
        console.log("");
    }

    /// @custom:senders owner
    function run() public broadcast {
        Senders.Sender storage ownerSender = sender("owner");

        // 1. Deploy new WormholeTransceiver implementation via CREATE3 with versioned label
        string memory label = string.concat(tokenName, ":", version);
        console.log("  > Deploying new WormholeTransceiver implementation (label: WormholeTransceiver:%s)", label);

        address newImpl = ownerSender
            .create3("WormholeTransceiver")
            .setLabel(label)
            .deploy(
                abi.encode(
                    localNttManagerProxy,
                    wormholeCoreBridge,
                    CONSISTENCY_LEVEL,
                    uint8(0), // customConsistencyLevel
                    uint16(0), // additionalBlocks
                    address(0) // customConsistencyLevelAddress
                )
            );

        console.log("  > New implementation deployed at: %s", newImpl);

        // 2. Upgrade proxy to new implementation
        console.log("  > Upgrading WormholeTransceiver proxy to new implementation...");
        ITransceiverUpgradeable(ownerSender.harness(localTransceiverProxy)).upgrade(newImpl);

        console.log("");
        console.log("=== UpgradeWormholeTransceiver: %s %s complete ===", tokenName, version);
    }

    // ── Config helpers ──────────────────────────────────────────────────

    function _loadConfig(string memory _tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(_tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(_tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("UpgradeWormholeTransceiver: unknown token: ", _tokenName));
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
        revert(string.concat("UpgradeWormholeTransceiver: current chain (", vm.toString(cid), ") not in config for ", config.tokenName));
    }
}
