// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NTTScriptBase} from "script/deploy/wormhole/NTTScriptBase.sol";
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
///        treb run UpgradeNttManager -e token=USDm -e NTT_VERSION=v2 --network celo
///        treb run UpgradeNttManager -e token=GBPm -e NTT_VERSION=v3 --network monad
contract UpgradeNttManager is NTTScriptBase {
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

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    /// @custom:env {string} NTT_VERSION - Version label for the new implementation (e.g. "v2")
    /// @custom:senders migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        // 1. Deploy new NttManager implementation via CREATE3 with versioned label
        string memory label = string.concat(tokenName, ":", version);
        console.log("  > Deploying new NttManager implementation (label: NttManagerImpl:%s)", label);

        address newImpl = owner
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
        INttManagerUpgradeable(owner.harness(localNttManagerProxy)).upgrade(newImpl);

        console.log("");
        console.log("=== UpgradeNttManager: %s %s complete ===", tokenName, version);
    }

}
