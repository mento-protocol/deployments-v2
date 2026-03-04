// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {NttDeployHelper} from "./NttDeployHelper.sol";

/// @title DeployNTT
/// @notice Treb-native deployment of NttManager + WormholeTransceiver ERC1967 proxies
///         for a given token on the current chain using CREATE3.
///
/// @dev Reads the NTT_TOKEN env var ("USDm" or "GBPm") to select the token config,
///      then deploys an NttDeployHelper via CREATE3 that bootstraps all NTT contracts
///      in its constructor. After deployment, proxy addresses can be read from
///      the helper contract.
///
///      Usage:
///        NTT_TOKEN=USDm treb run DeployNTT --network celo
///        NTT_TOKEN=GBPm treb run DeployNTT --network monad
contract DeployNTT is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @dev Default consistency level for WormholeTransceiver (200 = instant finality).
    uint8 constant CONSISTENCY_LEVEL = 200;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // ── Load config ─────────────────────────────────────────────────
        string memory tokenName = vm.envString("NTT_TOKEN");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory chainConfig = _findMyChain(config);

        // ── Resolve addresses ───────────────────────────────────────────
        address token = lookup(chainConfig.tokenLabel);
        address wormholeCoreBridge = lookup("WormholeCoreBridge");
        IManagerBase.Mode mode = chainConfig.isBurning
            ? IManagerBase.Mode.BURNING
            : IManagerBase.Mode.LOCKING;

        console.log("=== DeployNTT: %s on %s (chain %d) ===", config.tokenName, chainConfig.chainName, chainConfig.evmChainId);
        console.log("  Token:        %s (%s)", token, chainConfig.tokenLabel);
        console.log("  Mode:         %s", chainConfig.isBurning ? "burning" : "locking");
        console.log("  Wormhole ID:  %d", uint256(chainConfig.wormholeChainId));

        // ── Deploy via NttDeployHelper ───────────────────────────────────
        //    A single CREATE3 deployment that bootstraps NttManager +
        //    WormholeTransceiver proxies, initializes them, registers the
        //    transceiver, and transfers ownership to the deployer EOA.
        address helper = deployer
            .create3("NttDeployHelper")
            .setLabel(config.tokenName)
            .deploy(
                abi.encode(
                    token,
                    mode,
                    chainConfig.wormholeChainId,
                    wormholeCoreBridge,
                    CONSISTENCY_LEVEL,
                    deployer.account // initialOwner — enables harness calls in ConfigureNTT
                )
            );

        // ── Read deployed addresses ─────────────────────────────────────
        address nttManagerProxy = NttDeployHelper(helper).nttManagerProxy();
        address transceiverProxy = NttDeployHelper(helper).transceiverProxy();
        address nttManagerImpl = NttDeployHelper(helper).nttManagerImpl();
        address transceiverImpl = NttDeployHelper(helper).transceiverImpl();

        console.log("");
        console.log("  NttDeployHelper:           %s", helper);
        console.log("  NttManager impl:           %s", nttManagerImpl);
        console.log("  NttManager proxy:          %s", nttManagerProxy);
        console.log("  WormholeTransceiver impl:  %s", transceiverImpl);
        console.log("  WormholeTransceiver proxy: %s", transceiverProxy);
        console.log("  Owner:                     %s", deployer.account);
        console.log("");
        console.log("=== DeployNTT: %s complete ===", config.tokenName);
    }

    // ── Config helpers ──────────────────────────────────────────────────

    function _loadConfig(string memory tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("Unknown NTT_TOKEN: ", tokenName));
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
        revert(string.concat("Current chain (", vm.toString(cid), ") not found in NTT config for ", config.tokenName));
    }
}
