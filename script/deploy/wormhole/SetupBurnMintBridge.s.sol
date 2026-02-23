// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/Script.sol";
import {WormholeSetupBase, INTTManager, ITransceiver} from "./WormholeSetupBase.s.sol";
import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";

/// @title SetupBurnMintBridge
/// @notice Configures a burn-and-mint NTT bridge between Celo and Monad.
///         Both chains use burning mode. The NTT Manager on each chain needs
///         minter and burner permissions on the token contract.
///
///         Required env vars (see WormholeSetupBase):
///           CELO_NTT_MANAGER, CELO_TRANSCEIVER, CELO_INBOUND_LIMIT, CELO_V3_TOKEN
///           MONAD_NTT_MANAGER, MONAD_TRANSCEIVER, MONAD_INBOUND_LIMIT, MONAD_SPOKE_TOKEN
///
///         Run on each chain separately:
///           forge script SetupBurnMintBridge --rpc-url <celo-rpc>   --broadcast
///           forge script SetupBurnMintBridge --rpc-url <monad-rpc>  --broadcast
contract SetupBurnMintBridge is WormholeSetupBase {
    function setUp() public {
        _loadConfig();
    }

    function run() public {
        vm.startBroadcast();

        if (isCelo()) {
            console.log("=== SetupBurnMintBridge: Celo chain %d ===\n", CELO_CHAIN_ID);
            _setupCelo();
            _verifyCelo();
        } else if (isMonad()) {
            console.log("=== SetupBurnMintBridge: Monad chain %d ===\n", MONAD_CHAIN_ID);
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

        console.log("> Granting NTT Manager burn/mint permissions on token...");
        IStableTokenSpoke(celoV3Token).setBurner(celoNttManager, true);
        IStableTokenSpoke(celoV3Token).setMinter(celoNttManager, true);

        console.log(unicode"> Celo setup complete 👀\n");
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

        console.log("> Granting NTT Manager burn/mint permissions on token...");
        IStableTokenSpoke(monadSpokeToken).setBurner(monadNttManager, true);
        IStableTokenSpoke(monadSpokeToken).setMinter(monadNttManager, true);

        console.log(unicode"> Monad setup complete 👀\n");
    }

    // ── Verification ─────────────────────────────────────────────────────

    function _verifyCelo() internal view {
        console.log("== Verifying Celo ==");
        _verifyNttManagerPeer(celoNttManager, MONAD_WORMHOLE_CHAIN_ID, monadNttManager);
        _verifyTransceiverPeer(celoTransceiver, MONAD_WORMHOLE_CHAIN_ID, monadTransceiver);
        _verifyBurnMintPermissions(celoV3Token, celoNttManager);
        console.log(unicode"== Celo verification passed 🎉 ==\n");
    }

    function _verifyMonad() internal view {
        console.log("== Verifying Monad ==");
        _verifyNttManagerPeer(monadNttManager, CELO_WORMHOLE_CHAIN_ID, celoNttManager);
        _verifyTransceiverPeer(monadTransceiver, CELO_WORMHOLE_CHAIN_ID, celoTransceiver);
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
