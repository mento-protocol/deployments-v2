// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {WormholeSetupBase, INTTManager, ITransceiver} from "./WormholeSetupBase.s.sol";
import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";

/// @title SetupBurnMintBridge
/// @notice Configures a burn-and-mint NTT bridge between Celo and Monad.
///         Both chains use burning mode. The NTT Manager on each chain needs
///         minter and burner permissions on the token contract.
///         All config is read from a Wormhole NTT deployment JSON file.
///
///         Usage:
///           1. Drop the Wormhole NTT deployment JSON into script/deploy/wormhole/configs/
///           2. Run on each chain separately:
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/GBPm.json \
///             treb run SetupBurnMintBridge --network celo
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/GBPm.json \
///             treb run SetupBurnMintBridge --network monad
contract SetupBurnMintBridge is WormholeSetupBase {
    using Senders for Senders.Sender;

    function setUp() public {
        _loadConfig();
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        if (isCelo()) {
            console.log("=== SetupBurnMintBridge: Celo chain %d ===\n", CELO_CHAIN_ID);
            _setupCelo(deployer);
            _verifyCelo();
        } else if (isMonad()) {
            console.log("=== SetupBurnMintBridge: Monad chain %d ===\n", MONAD_CHAIN_ID);
            _setupMonad(deployer);
            _verifyMonad();
        } else {
            revert("Unsupported chain");
        }
    }

    // ── Setup ────────────────────────────────────────────────────────────

    function _setupCelo(Senders.Sender storage deployer) internal {
        console.log("> Setting NTT Manager peer...");
        INTTManager(deployer.harness(celoNttManager)).setPeer(
            MONAD_WORMHOLE_CHAIN_ID,
            _toBytes32(monadNttManager),
            TOKEN_DECIMALS,
            celoInboundLimit
        );

        console.log("> Setting Transceiver wormhole peer...");
        ITransceiver(deployer.harness(celoTransceiver)).setWormholePeer(
            MONAD_WORMHOLE_CHAIN_ID,
            _toBytes32(monadTransceiver)
        );

        console.log("> Setting outbound limit...");
        INTTManager(deployer.harness(celoNttManager)).setOutboundLimit(celoOutboundLimit);

        console.log("> Granting NTT Manager burn/mint permissions on token...");
        IStableTokenSpoke(deployer.harness(celoV3Token)).setBurner(celoNttManager, true);
        IStableTokenSpoke(deployer.harness(celoV3Token)).setMinter(celoNttManager, true);

        console.log(unicode"> Celo setup complete 👀\n");
    }

    function _setupMonad(Senders.Sender storage deployer) internal {
        console.log("> Setting NTT Manager peer...");
        INTTManager(deployer.harness(monadNttManager)).setPeer(
            CELO_WORMHOLE_CHAIN_ID,
            _toBytes32(celoNttManager),
            TOKEN_DECIMALS,
            monadInboundLimit
        );

        console.log("> Setting Transceiver wormhole peer...");
        ITransceiver(deployer.harness(monadTransceiver)).setWormholePeer(
            CELO_WORMHOLE_CHAIN_ID,
            _toBytes32(celoTransceiver)
        );

        console.log("> Setting outbound limit...");
        INTTManager(deployer.harness(monadNttManager)).setOutboundLimit(monadOutboundLimit);

        console.log("> Granting NTT Manager burn/mint permissions on token...");
        IStableTokenSpoke(deployer.harness(monadSpokeToken)).setBurner(monadNttManager, true);
        IStableTokenSpoke(deployer.harness(monadSpokeToken)).setMinter(monadNttManager, true);

        console.log(unicode"> Monad setup complete 👀\n");
    }

    // ── Verification ─────────────────────────────────────────────────────

    function _verifyCelo() internal view {
        console.log("== Verifying Celo ==");
        _verifyNttManagerPeer(celoNttManager, MONAD_WORMHOLE_CHAIN_ID, monadNttManager);
        _verifyTransceiverPeer(celoTransceiver, MONAD_WORMHOLE_CHAIN_ID, monadTransceiver);
        _verifyOutboundLimit(celoNttManager, celoOutboundLimit);
        _verifyBurnMintPermissions(celoV3Token, celoNttManager);
        console.log(unicode"== Celo verification passed 🎉 ==\n");
    }

    function _verifyMonad() internal view {
        console.log("== Verifying Monad ==");
        _verifyNttManagerPeer(monadNttManager, CELO_WORMHOLE_CHAIN_ID, celoNttManager);
        _verifyTransceiverPeer(monadTransceiver, CELO_WORMHOLE_CHAIN_ID, celoTransceiver);
        _verifyOutboundLimit(monadNttManager, monadOutboundLimit);
        _verifyBurnMintPermissions(monadSpokeToken, monadNttManager);
        console.log(unicode"== Monad verification passed 🎉 ==\n");
    }

    function _verifyBurnMintPermissions(address token, address manager) internal view {
        console.log("  Verifying burn/mint permissions on token %s", token);
        require(IStableTokenSpoke(token).isMinter(manager), "NTT Manager is not a minter");
        require(IStableTokenSpoke(token).isBurner(manager), "NTT Manager is not a burner");
        console.log("  -> NTT Manager %s has minter and burner roles", manager);
    }
}
