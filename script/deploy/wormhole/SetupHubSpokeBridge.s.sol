// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/Script.sol";
import {WormholeSetupBase, INTTManager, ITransceiver} from "./WormholeSetupBase.s.sol";
import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";

/// @title SetupHubSpokeBridge
/// @notice Configures a hub-and-spoke (locking) NTT bridge between Celo (hub) and Monad (spoke).
///         Celo locks tokens, Monad burns/mints. All config is read from a Wormhole NTT
///         deployment JSON file.
///
///         Usage:
///           1. Drop the Wormhole NTT deployment JSON into script/deploy/wormhole/configs/
///           2. Run on each chain separately:
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/USDm.json \
///             forge script SetupHubSpokeBridge --rpc-url <celo-rpc>  --broadcast
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/USDm.json \
///             forge script SetupHubSpokeBridge --rpc-url <monad-rpc> --broadcast
contract SetupHubSpokeBridge is WormholeSetupBase {
    function setUp() public {
        _loadConfig();
    }

    function run() public {
        vm.startBroadcast();

        if (isCelo()) {
            console.log("=== SetupHubSpokeBridge: Celo (Hub) chain %d ===\n", CELO_CHAIN_ID);
            _setupCelo();
            _verifyCelo();
        } else if (isMonad()) {
            console.log("=== SetupHubSpokeBridge: Monad (Spoke) chain %d ===\n", MONAD_CHAIN_ID);
            _setupMonad();
            _verifyMonad();
        } else {
            revert("Unsupported chain");
        }

        vm.stopBroadcast();
    }

    // ── Setup ────────────────────────────────────────────────────────────

    function _setupCelo() internal {
        console.log("> Setting NTT Manager peer...");
        INTTManager(celoNttManager).setPeer(
            MONAD_WORMHOLE_CHAIN_ID,
            _toBytes32(monadNttManager),
            TOKEN_DECIMALS,
            celoInboundLimit
        );

        console.log("> Setting Transceiver wormhole peer...");
        ITransceiver(celoTransceiver).setWormholePeer(
            MONAD_WORMHOLE_CHAIN_ID,
            _toBytes32(monadTransceiver)
        );

        console.log("> Setting outbound limit...");
        INTTManager(celoNttManager).setOutboundLimit(celoOutboundLimit);

        console.log(unicode"> Celo (Hub) setup complete 👀\n");
    }

    function _setupMonad() internal {
        console.log("> Setting NTT Manager peer...");
        INTTManager(monadNttManager).setPeer(
            CELO_WORMHOLE_CHAIN_ID,
            _toBytes32(celoNttManager),
            TOKEN_DECIMALS,
            monadInboundLimit
        );

        console.log("> Setting Transceiver wormhole peer...");
        ITransceiver(monadTransceiver).setWormholePeer(
            CELO_WORMHOLE_CHAIN_ID,
            _toBytes32(celoTransceiver)
        );

        console.log("> Setting outbound limit...");
        INTTManager(monadNttManager).setOutboundLimit(monadOutboundLimit);

        console.log("> Granting NTT Manager burn/mint permissions on spoke token...");
        IStableTokenSpoke(monadSpokeToken).setBurner(monadNttManager, true);
        IStableTokenSpoke(monadSpokeToken).setMinter(monadNttManager, true);

        console.log(unicode"> Monad (Spoke) setup complete 👀\n");
    }

    // ── Verification ─────────────────────────────────────────────────────

    function _verifyCelo() internal view {
        console.log("== Verifying Celo (Hub) ==");
        _verifyNttManagerPeer(celoNttManager, MONAD_WORMHOLE_CHAIN_ID, monadNttManager);
        _verifyTransceiverPeer(celoTransceiver, MONAD_WORMHOLE_CHAIN_ID, monadTransceiver);
        _verifyOutboundLimit(celoNttManager, celoOutboundLimit);
        console.log(unicode"== Celo (Hub) verification passed 🎉 ==\n");
    }

    function _verifyMonad() internal view {
        console.log("== Verifying Monad (Spoke) ==");
        _verifyNttManagerPeer(monadNttManager, CELO_WORMHOLE_CHAIN_ID, celoNttManager);
        _verifyTransceiverPeer(monadTransceiver, CELO_WORMHOLE_CHAIN_ID, celoTransceiver);
        _verifyOutboundLimit(monadNttManager, monadOutboundLimit);
        _verifyBurnMintPermissions(monadSpokeToken, monadNttManager);
        console.log(unicode"== Monad (Spoke) verification passed 🎉 ==\n");
    }

    function _verifyBurnMintPermissions(address token, address manager) internal view {
        console.log("  Verifying burn/mint permissions on token %s", token);
        require(IStableTokenSpoke(token).isMinter(manager), "NTT Manager is not a minter");
        require(IStableTokenSpoke(token).isBurner(manager), "NTT Manager is not a burner");
        console.log("  -> NTT Manager %s has minter and burner roles", manager);
    }
}
