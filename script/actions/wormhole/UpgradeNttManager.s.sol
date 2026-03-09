// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {INttDeployHelper} from "./interfaces/INttDeployHelper.sol";
import {INttManagerUpgradeable} from "./interfaces/INttManagerUpgradeable.sol";

// ── Script ────────────────────────────────────────────────────────────────

/// @title UpgradeNttManager
/// @notice Governance action to upgrade the NttManager implementation without
///         redeploying the proxy.
///
/// @dev Deploys a new NttManager implementation via CREATE3 with a versioned
///      label, then calls upgrade() on the existing proxy. The new implementation
///      must be constructed with identical immutables (token, mode, chainId,
///      rateLimitDuration) so that _checkImmutables() passes during the upgrade.
///
///      Usage:
///        token=USDm NTT_VERSION=v2 treb run UpgradeNttManager --network celo
///        token=GBPm NTT_VERSION=v3 treb run UpgradeNttManager --network monad
contract UpgradeNttManager is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    // ── Constants ─────────────────────────────────────────────────────────
    uint64 constant RATE_LIMIT_DURATION = 86400; // 24 hours

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    string internal version;
    address internal localNttManagerProxy;
    address internal token;
    IManagerBase.Mode internal mode;
    uint16 internal wormholeChainId;

    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        version = vm.envString("NTT_VERSION");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory chainConfig = _findMyChain(config);

        // Resolve local NttManager proxy from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "UpgradeNttManager: local NttDeployHelper not found in registry");
        localNttManagerProxy = INttDeployHelper(localHelper).nttManagerProxy();

        // Store constructor params — must match original deployment for _checkImmutables()
        token = lookup(chainConfig.tokenLabel);
        mode = chainConfig.isBurning ? IManagerBase.Mode.BURNING : IManagerBase.Mode.LOCKING;
        wormholeChainId = chainConfig.wormholeChainId;

        console.log("=== UpgradeNttManager: %s %s on %s ===", tokenName, version, chainConfig.chainName);
        console.log("  NttManager proxy: %s", localNttManagerProxy);
        console.log("  Token:            %s", token);
        console.log("  Mode:             %s", chainConfig.isBurning ? "burning" : "locking");
        console.log("");
    }

    /// @custom:senders owner
    function run() public broadcast {
        Senders.Sender storage ownerSender = sender("owner");

        // 1. Deploy new NttManager implementation via CREATE3 with versioned label
        string memory label = string.concat(tokenName, ":", version);
        console.log("  > Deploying new NttManager implementation (label: NttManagerImpl:%s)", label);

        address newImpl = ownerSender
            .create3("NttManager")
            .setLabel(label)
            .deploy(
                abi.encode(
                    token,
                    mode,
                    wormholeChainId,
                    RATE_LIMIT_DURATION,
                    false // don't skip rate limiting
                )
            );

        console.log("  > New implementation deployed at: %s", newImpl);

        // 2. Upgrade proxy to new implementation
        console.log("  > Upgrading NttManager proxy to new implementation...");
        INttManagerUpgradeable(ownerSender.harness(localNttManagerProxy)).upgrade(newImpl);

        console.log("");
        console.log("=== UpgradeNttManager: %s %s complete ===", tokenName, version);
    }

    // ── Config helpers ──────────────────────────────────────────────────

    function _loadConfig(string memory _tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(_tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(_tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("UpgradeNttManager: unknown token: ", _tokenName));
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
        revert(string.concat("UpgradeNttManager: current chain (", vm.toString(cid), ") not in config for ", config.tokenName));
    }
}
