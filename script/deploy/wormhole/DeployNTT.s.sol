// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";
import {NTTScriptBase} from "script/deploy/wormhole/NTTScriptBase.sol";
import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {INttDeployHelper} from "script/actions/wormhole/interfaces/INttDeployHelper.sol";

/// @title DeployNTT
/// @notice Treb-native deployment of NttManager + WormholeTransceiver ERC1967 proxies
///         for a given token on the current chain using CREATE3.
///
/// @dev Reads the token env var ("USDm" or "GBPm") to select the token config,
///      then deploys an NttDeployHelper via CREATE3 that bootstraps all NTT contracts
///      in its constructor. After deployment, proxy addresses can be read from
///      the helper contract.
///
///      The TransceiverStructs library must be deployed on the network before
///      running this script (see DeployTransceiverStructs.s.sol).
///
///      Usage:
///        treb run DeployNTT -e token=USDm --network celo
///        treb run DeployNTT -e token=GBPm --network monad
contract DeployNTT is NTTScriptBase {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @dev Default consistency level for WormholeTransceiver (202 = finalized).
    uint8 constant CONSISTENCY_LEVEL = 202;

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // ── Load config ─────────────────────────────────────────────────
        string memory tokenName = vm.envString("token");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        NTTChainConfig memory chainConfig = _findMyChain(config);

        // ── Resolve addresses ───────────────────────────────────────────
        address token = lookupProxyOrFail(chainConfig.tokenLabel);
        address wormholeCoreBridge = lookupOrFail("WormholeCoreBridge");
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
        address nttManagerProxy = INttDeployHelper(helper).nttManagerProxy();
        address transceiverProxy = INttDeployHelper(helper).transceiverProxy();
        address nttManagerImpl = INttDeployHelper(helper).nttManagerImpl();
        address transceiverImpl = INttDeployHelper(helper).transceiverImpl();

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
}
