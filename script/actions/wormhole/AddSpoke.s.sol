// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig, NTTInboundLimit} from "script/config/wormhole/NTTConfig.sol";
import {NttDeployHelper} from "script/deploy/wormhole/NttDeployHelper.sol";
import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

// ── Wormhole NTT on-chain interfaces ────────────────────────────────────────

/// @dev NTT Manager peer info returned by getPeer()
struct NttManagerPeer {
    bytes32 peerAddress;
    uint8 tokenDecimals;
}

/// @dev Rate limit parameters returned by getInboundLimitParams() / getOutboundLimitParams()
struct RateLimitParams {
    uint72 limit; // TrimmedAmount (packed: amount << 8 | decimals)
    uint72 currentCapacity; // TrimmedAmount
    uint64 lastTxTimestamp;
}

interface INTTManager {
    function setPeer(uint16 peerChainId, bytes32 peerContract, uint8 decimals, uint256 inboundLimit) external;
    function getPeer(uint16 chainId) external view returns (NttManagerPeer memory);
    function setInboundLimit(uint256 limit, uint16 chainId_) external;
    function setOutboundLimit(uint256 limit) external;
    function getOutboundLimitParams() external view returns (RateLimitParams memory);
    function getInboundLimitParams(uint16 chainId_) external view returns (RateLimitParams memory);
}

interface ITransceiver {
    function setWormholePeer(uint16 chainId, bytes32 peerContract) external payable;
    function getWormholePeer(uint16 chainId) external view returns (bytes32);
}

interface IPausable {
    function pauser() external view returns (address);
    function transferPauserCapability(address newPauser) external;
}

// ── Script ──────────────────────────────────────────────────────────────────

/// @title AddSpoke
/// @notice Deploys and configures NTT contracts on a new spoke chain in a single step.
///
/// @dev Adding a spoke to an existing NTT bridge is a two-phase process:
///
///      Phase 1 (this script): Run on the NEW spoke chain.
///        - Deploys NttManager + WormholeTransceiver via NttDeployHelper
///        - Configures peers pointing to all existing chains
///        - Sets rate limits
///        - Grants burn/mint permissions if spoke is in burning mode
///        - Transfers ownership to the configured owner
///
///      Phase 2 (separate governance action): Run on EACH existing chain.
///        - Each existing chain must add the new spoke as a peer via ConfigureNTT
///          or a governance proposal calling setPeer() + setWormholePeer().
///        - This requires governance approval on each existing chain.
///
///      Usage:
///        treb run AddSpoke -e token=USDm --network <new-spoke-network>
///        treb run AddSpoke -e token=GBPm --network <new-spoke-network>
contract AddSpoke is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @dev Default consistency level for WormholeTransceiver (200 = instant finality).
    uint8 constant CONSISTENCY_LEVEL = 200;
    /// @dev NttDeployHelper internal CREATE nonce for NttManager proxy.
    uint256 constant HELPER_NONCE_NTT_MANAGER_PROXY = 2;
    /// @dev NttDeployHelper internal CREATE nonce for WormholeTransceiver proxy.
    uint256 constant HELPER_NONCE_TRANSCEIVER_PROXY = 4;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    uint8 internal tokenDecimals;
    NTTChainConfig internal myChain;
    NTTChainConfig[] internal peerChains;
    address[] internal remoteNttManagers;
    address[] internal remoteTransceivers;
    uint256[] internal peerInboundLimits;
    address internal owner;

    /// @custom:env {string} token - Token name (e.g. "USDm", "GBPm")
    function setUp() public {
        // Load config
        tokenName = vm.envString("token");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        tokenDecimals = config.tokenDecimals;

        // Find current chain
        NTTChainConfig memory _myChain = _findMyChain(config);
        myChain = _myChain;

        // Resolve owner
        owner = lookup(config.ownerLabel);
        require(owner != address(0), string.concat("AddSpoke: owner '", config.ownerLabel, "' not found"));

        // Resolve remote peers (existing chains)
        string memory ns = vm.envOr("NAMESPACE", string("default"));
        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].evmChainId == _myChain.evmChainId) continue;

            NTTChainConfig memory peer = config.chains[i];
            peerChains.push(peer);

            address remoteHelper = lookup(
                string.concat("NttDeployHelper:", tokenName),
                ns,
                vm.toString(peer.evmChainId)
            );
            require(
                remoteHelper != address(0),
                string.concat("AddSpoke: remote NttDeployHelper not found for chain ", vm.toString(peer.evmChainId))
            );

            remoteNttManagers.push(vm.computeCreateAddress(remoteHelper, HELPER_NONCE_NTT_MANAGER_PROXY));
            remoteTransceivers.push(vm.computeCreateAddress(remoteHelper, HELPER_NONCE_TRANSCEIVER_PROXY));
            peerInboundLimits.push(_findInboundLimit(config, peer.chainName));
        }

        console.log("=== AddSpoke: %s on %s (chain %d) ===", tokenName, _myChain.chainName, _myChain.evmChainId);
        console.log("  Mode:   %s", _myChain.isBurning ? "burning" : "locking");
        console.log("  Owner:  %s", owner);
        console.log("  Peers:  %d existing chain(s)", peerChains.length);
        console.log("");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // ── Phase 1a: Deploy NTT contracts ───────────────────────────────
        (address localNttManager, address localTransceiver) = _deploy(deployer);

        // ── Phase 1b: Configure peers ────────────────────────────────────
        for (uint256 i = 0; i < peerChains.length; i++) {
            _setupPeer(deployer, localNttManager, localTransceiver, i);
        }

        // ── Phase 1c: Set outbound rate limit ────────────────────────────
        _setupOutboundLimit(deployer, localNttManager);

        // ── Phase 1d: Grant burn/mint permissions if burning mode ─────────
        if (myChain.isBurning) {
            _setupBurnMintPermissions(deployer, localNttManager);
        }

        // ── Phase 1e: Transfer ownership and pauser ──────────────────────
        _setupOwnership(deployer, localNttManager, localTransceiver);

        // ── Phase 2 reminder ─────────────────────────────────────────────
        console.log("");
        console.log("=== AddSpoke: %s Phase 1 complete ===", tokenName);
        console.log("");
        console.log("!! IMPORTANT: Phase 2 required !!");
        console.log("   Each existing chain must add this spoke as a peer.");
        console.log("   Run ConfigureNTT or submit a governance proposal on each existing chain");
        console.log("   to call setPeer() and setWormholePeer() with this spoke's addresses.");
        for (uint256 i = 0; i < peerChains.length; i++) {
            console.log("   - %s (chain %d): governance action needed", peerChains[i].chainName, peerChains[i].evmChainId);
        }
    }

    // ── Deploy helper ───────────────────────────────────────────────────

    function _deploy(Senders.Sender storage deployer) internal returns (address nttManagerProxy, address transceiverProxy) {
        address token = lookup(myChain.tokenLabel);
        address wormholeCoreBridge = lookup("WormholeCoreBridge");
        IManagerBase.Mode mode = myChain.isBurning
            ? IManagerBase.Mode.BURNING
            : IManagerBase.Mode.LOCKING;

        console.log("  Deploying NTT contracts...");
        console.log("    Token:       %s (%s)", token, myChain.tokenLabel);
        console.log("    Wormhole ID: %d", uint256(myChain.wormholeChainId));

        address helper = deployer
            .create3("NttDeployHelper")
            .setLabel(tokenName)
            .deploy(
                abi.encode(
                    token,
                    mode,
                    myChain.wormholeChainId,
                    wormholeCoreBridge,
                    CONSISTENCY_LEVEL,
                    deployer.account
                )
            );

        nttManagerProxy = NttDeployHelper(helper).nttManagerProxy();
        transceiverProxy = NttDeployHelper(helper).transceiverProxy();

        console.log("    NttDeployHelper:           %s", helper);
        console.log("    NttManager proxy:          %s", nttManagerProxy);
        console.log("    WormholeTransceiver proxy: %s", transceiverProxy);
        console.log("");
    }

    // ── Configuration helpers (idempotent) ──────────────────────────────

    function _setupPeer(
        Senders.Sender storage deployer,
        address localNttManager,
        address localTransceiver,
        uint256 peerIdx
    ) internal {
        NTTChainConfig memory peer = peerChains[peerIdx];
        address remoteManager = remoteNttManagers[peerIdx];
        address remoteXceiver = remoteTransceivers[peerIdx];
        uint256 inboundLimit = peerInboundLimits[peerIdx];

        console.log("  Peer: %s (wormhole chain %d)", peer.chainName, uint256(peer.wormholeChainId));

        // NTT Manager peer
        bytes32 expectedPeerManager = _toBytes32(remoteManager);
        NttManagerPeer memory existingPeer = INTTManager(localNttManager).getPeer(peer.wormholeChainId);

        if (existingPeer.peerAddress != expectedPeerManager) {
            console.log("    > Setting NTT Manager peer...");
            INTTManager(deployer.harness(localNttManager)).setPeer(
                peer.wormholeChainId,
                expectedPeerManager,
                tokenDecimals,
                inboundLimit
            );
        } else {
            console.log("    > NTT Manager peer already set, checking inbound limit...");
            uint256 currentInbound = _untrim(
                INTTManager(localNttManager).getInboundLimitParams(peer.wormholeChainId).limit
            );
            if (currentInbound != inboundLimit) {
                console.log("    > Updating inbound limit...");
                INTTManager(deployer.harness(localNttManager)).setInboundLimit(inboundLimit, peer.wormholeChainId);
            } else {
                console.log("    > Inbound limit already correct");
            }
        }

        // Transceiver wormhole peer
        bytes32 expectedPeerXceiver = _toBytes32(remoteXceiver);
        if (ITransceiver(localTransceiver).getWormholePeer(peer.wormholeChainId) != expectedPeerXceiver) {
            console.log("    > Setting Transceiver wormhole peer...");
            ITransceiver(deployer.harness(localTransceiver)).setWormholePeer(
                peer.wormholeChainId,
                expectedPeerXceiver
            );
        } else {
            console.log("    > Transceiver wormhole peer already set");
        }
    }

    function _setupOutboundLimit(Senders.Sender storage deployer, address localNttManager) internal {
        uint256 currentOutbound = _untrim(INTTManager(localNttManager).getOutboundLimitParams().limit);
        if (currentOutbound != myChain.outboundLimit) {
            console.log("  > Setting outbound limit to %d...", myChain.outboundLimit / 1e18);
            INTTManager(deployer.harness(localNttManager)).setOutboundLimit(myChain.outboundLimit);
        } else {
            console.log("  > Outbound limit already correct, skipping");
        }
    }

    function _setupBurnMintPermissions(Senders.Sender storage deployer, address localNttManager) internal {
        address token = lookup(myChain.tokenLabel);

        if (!IStableTokenSpoke(token).isBurner(localNttManager)) {
            console.log("  > Granting NTT Manager burner permission...");
            IStableTokenSpoke(deployer.harness(token)).setBurner(localNttManager, true);
        } else {
            console.log("  > NTT Manager already has burner permission, skipping");
        }

        if (!IStableTokenSpoke(token).isMinter(localNttManager)) {
            console.log("  > Granting NTT Manager minter permission...");
            IStableTokenSpoke(deployer.harness(token)).setMinter(localNttManager, true);
        } else {
            console.log("  > NTT Manager already has minter permission, skipping");
        }
    }

    function _setupOwnership(
        Senders.Sender storage deployer,
        address localNttManager,
        address localTransceiver
    ) internal {
        // NTT Manager ownership (cascades to all registered transceivers)
        if (IOwnable(localNttManager).owner() != owner) {
            console.log("  > Transferring NTT Manager ownership to %s...", owner);
            IOwnable(deployer.harness(localNttManager)).transferOwnership(owner);
        } else {
            console.log("  > NTT Manager already owned by %s, skipping", owner);
        }

        // Pauser capability does NOT cascade — must be set on each contract
        if (IPausable(localNttManager).pauser() != owner) {
            console.log("  > Transferring NTT Manager pauser to %s...", owner);
            IPausable(deployer.harness(localNttManager)).transferPauserCapability(owner);
        } else {
            console.log("  > NTT Manager pauser already correct, skipping");
        }

        if (IPausable(localTransceiver).pauser() != owner) {
            console.log("  > Transferring Transceiver pauser to %s...", owner);
            IPausable(deployer.harness(localTransceiver)).transferPauserCapability(owner);
        } else {
            console.log("  > Transceiver pauser already correct, skipping");
        }
    }

    // ── Config helpers ──────────────────────────────────────────────────

    function _loadConfig(string memory _tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(_tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(_tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("AddSpoke: unknown token: ", _tokenName));
        }
    }

    function _findMyChain(NTTTokenConfig memory config) internal view returns (NTTChainConfig memory) {
        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].evmChainId == block.chainid) return config.chains[i];
        }
        revert(string.concat("AddSpoke: current chain (", vm.toString(block.chainid), ") not in config for ", config.tokenName));
    }

    function _findInboundLimit(NTTTokenConfig memory config, string memory fromChainName) internal pure returns (uint256) {
        for (uint256 i = 0; i < config.inboundLimits.length; i++) {
            if (keccak256(bytes(config.inboundLimits[i].fromChainName)) == keccak256(bytes(fromChainName))) {
                return config.inboundLimits[i].limit;
            }
        }
        revert(string.concat("AddSpoke: no inbound limit from chain '", fromChainName, "'"));
    }

    // ── Pure helpers ────────────────────────────────────────────────────

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

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
