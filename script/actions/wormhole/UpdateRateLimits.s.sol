// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig, NTTInboundLimit} from "script/config/wormhole/NTTConfig.sol";
import {NTTScriptBase} from "script/deploy/wormhole/NTTScriptBase.sol";
import {INttDeployHelper} from "./interfaces/INttDeployHelper.sol";
import {INTTManager, RateLimitParams} from "./interfaces/INTTManager.sol";

// ── Script ──────────────────────────────────────────────────────────────────

/// @title UpdateRateLimits
/// @notice Governance action to update NTT rate limits without redeployment.
///
/// @dev Reads updated limits from NTTConfig and applies them idempotently.
///      The NttManager must be owned by the governance sender (e.g. MigrationMultisig).
///
///      Usage:
///        treb run UpdateRateLimits -e token=USDm --network celo
///        treb run UpdateRateLimits -e token=GBPm --network monad
contract UpdateRateLimits is NTTScriptBase {
    using Senders for Senders.Sender;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    uint8 internal tokenDecimals;
    address internal localNttManager;
    NTTChainConfig internal myChain;
    NTTChainConfig[] internal peerChains;
    uint256[] internal peerInboundLimits;

    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        tokenDecimals = config.tokenDecimals;

        // Find current chain
        NTTChainConfig memory _myChain = _findMyChain(config);
        myChain = _myChain;

        // Resolve local NttManager from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "UpdateRateLimits: local NttDeployHelper not found in registry");
        localNttManager = INttDeployHelper(localHelper).nttManagerProxy();

        // Collect peer chains and their inbound limits
        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].evmChainId == _myChain.evmChainId) continue;

            peerChains.push(config.chains[i]);
            peerInboundLimits.push(_findInboundLimit(config, config.chains[i].chainName));
        }

        console.log("=== UpdateRateLimits: %s on %s (chain %d) ===", tokenName, _myChain.chainName, _myChain.evmChainId);
        console.log("  NttManager: %s", localNttManager);
        console.log("");
    }

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    /// @custom:senders owner
    function run() public broadcast {
        Senders.Sender storage ownerSender = sender("owner");

        // 1. Update outbound limit
        _updateOutboundLimit(ownerSender);

        // 2. Update inbound limits per peer chain
        for (uint256 i = 0; i < peerChains.length; i++) {
            _updateInboundLimit(ownerSender, i);
        }

        console.log("");
        console.log("=== UpdateRateLimits: %s complete ===", tokenName);
    }

    // ── Rate limit helpers (idempotent) ─────────────────────────────────

    function _updateOutboundLimit(Senders.Sender storage ownerSender) internal {
        uint256 currentOutbound = _untrim(INTTManager(localNttManager).getOutboundLimitParams().limit);
        if (currentOutbound != myChain.outboundLimit) {
            console.log("  > Updating outbound limit: %d -> %d", currentOutbound / 1e18, myChain.outboundLimit / 1e18);
            INTTManager(ownerSender.harness(localNttManager)).setOutboundLimit(myChain.outboundLimit);
        } else {
            console.log("  > Outbound limit already correct (%d), skipping", currentOutbound / 1e18);
        }
    }

    function _updateInboundLimit(Senders.Sender storage ownerSender, uint256 peerIdx) internal {
        NTTChainConfig memory peer = peerChains[peerIdx];
        uint256 desiredLimit = peerInboundLimits[peerIdx];
        uint256 currentInbound = _untrim(
            INTTManager(localNttManager).getInboundLimitParams(peer.wormholeChainId).limit
        );

        if (currentInbound != desiredLimit) {
            console.log(
                "  > Updating inbound limit from %s: %d -> %d",
                peer.chainName,
                currentInbound / 1e18,
                desiredLimit / 1e18
            );
            INTTManager(ownerSender.harness(localNttManager)).setInboundLimit(desiredLimit, peer.wormholeChainId);
        } else {
            console.log("  > Inbound limit from %s already correct (%d), skipping", peer.chainName, currentInbound / 1e18);
        }
    }

    // ── Config helpers ──────────────────────────────────────────────────

    function _findInboundLimit(NTTTokenConfig memory config, string memory fromChainName) internal pure returns (uint256) {
        for (uint256 i = 0; i < config.inboundLimits.length; i++) {
            if (keccak256(bytes(config.inboundLimits[i].fromChainName)) == keccak256(bytes(fromChainName))) {
                return config.inboundLimits[i].limit;
            }
        }
        revert(string.concat("UpdateRateLimits: no inbound limit from chain '", fromChainName, "'"));
    }

    // ── Pure helpers ────────────────────────────────────────────────────

    /// @dev Decode a TrimmedAmount (uint72) back to a full-precision value.
    ///      TrimmedAmount packs: (amount << 8) | trimmedDecimals
    function _untrim(uint72 packed) internal view returns (uint256) {
        uint8 decimals = uint8(packed & 0xFF);
        uint64 amount = uint64(packed >> 8);
        uint8 td = tokenDecimals;
        if (decimals == td) return uint256(amount);
        if (decimals < td) return uint256(amount) * 10 ** (td - decimals);
        return uint256(amount) / 10 ** (decimals - td);
    }
}
