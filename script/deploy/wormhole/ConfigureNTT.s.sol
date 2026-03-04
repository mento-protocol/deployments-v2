// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig, NTTInboundLimit} from "script/config/wormhole/NTTConfig.sol";
import {NttDeployHelper} from "./NttDeployHelper.sol";
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

/// @title ConfigureNTT
/// @notice Treb-native configuration of NTT bridge: peer registration, rate limits,
///         burn/mint permissions, and ownership transfer.
///
/// @dev Run AFTER DeployNTT has been executed on ALL chains.
///      This script configures the current chain's NttManager and WormholeTransceiver
///      with peers from all remote chains, sets rate limits, and transfers ownership.
///
///      Local NTT contracts are resolved via treb registry lookup of NttDeployHelper,
///      then reading proxy addresses from its immutables.
///      Remote NTT contracts are resolved via cross-chain registry lookup of the
///      remote NttDeployHelper, then computing proxy addresses via CREATE nonce derivation.
///
///      All operations are idempotent: existing state is checked before writing.
///
///      Usage (run once per token per chain, after DeployNTT on all chains):
///
///        NTT_TOKEN=USDm treb run ConfigureNTT --network celo
///        NTT_TOKEN=GBPm treb run ConfigureNTT --network monad
contract ConfigureNTT is TrebScript {
    using Senders for Senders.Sender;

    /// @dev NttDeployHelper internal CREATE nonce for NttManager proxy (2nd deployment in constructor).
    uint256 constant HELPER_NONCE_NTT_MANAGER_PROXY = 2;
    /// @dev NttDeployHelper internal CREATE nonce for WormholeTransceiver proxy (4th deployment in constructor).
    uint256 constant HELPER_NONCE_TRANSCEIVER_PROXY = 4;

    // ── Storage (set in setUp, read in run — avoids stack-too-deep) ─────
    string internal tokenName;
    uint8 internal tokenDecimals;
    address internal localNttManager;
    address internal localTransceiver;
    address internal owner;
    NTTChainConfig internal myChain;
    NTTChainConfig[] internal peerChains;
    address[] internal remoteNttManagers;
    address[] internal remoteTransceivers;
    uint256[] internal peerInboundLimits;

    function setUp() public {
        // Load config
        tokenName = vm.envString("NTT_TOKEN");
        NTTTokenConfig memory config = _loadConfig(tokenName);
        tokenDecimals = config.tokenDecimals;

        // Find current chain
        NTTChainConfig memory _myChain = _findMyChain(config);
        myChain = _myChain;

        // Resolve local NTT contracts from registry
        address localHelper = lookup(string.concat("NttDeployHelper:", tokenName));
        require(localHelper != address(0), "ConfigureNTT: local NttDeployHelper not found in registry");
        localNttManager = NttDeployHelper(localHelper).nttManagerProxy();
        localTransceiver = NttDeployHelper(localHelper).transceiverProxy();

        // Resolve owner
        owner = lookup(config.ownerLabel);
        require(owner != address(0), string.concat("ConfigureNTT: owner '", config.ownerLabel, "' not found"));

        // Resolve remote peers
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
                string.concat("ConfigureNTT: remote NttDeployHelper not found for chain ", vm.toString(peer.evmChainId))
            );

            remoteNttManagers.push(vm.computeCreateAddress(remoteHelper, HELPER_NONCE_NTT_MANAGER_PROXY));
            remoteTransceivers.push(vm.computeCreateAddress(remoteHelper, HELPER_NONCE_TRANSCEIVER_PROXY));
            peerInboundLimits.push(_findInboundLimit(config, peer.chainName));
        }

        console.log("=== ConfigureNTT: %s on %s (chain %d) ===", tokenName, _myChain.chainName, _myChain.evmChainId);
        console.log("  NttManager:   %s", localNttManager);
        console.log("  Transceiver:  %s", localTransceiver);
        console.log("  Mode:         %s", _myChain.isBurning ? "burning" : "locking");
        console.log("  Owner:        %s", owner);
        console.log("");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // 1. Configure peers
        for (uint256 i = 0; i < peerChains.length; i++) {
            _setupPeer(deployer, i);
        }

        // 2. Set outbound rate limit
        _setupOutboundLimit(deployer);

        // 3. Grant burn/mint permissions if burning mode
        if (myChain.isBurning) {
            _setupBurnMintPermissions(deployer);
        }

        // 4. Transfer ownership and pauser
        _setupOwnership(deployer);

        console.log("");
        console.log("=== ConfigureNTT: %s complete ===", tokenName);
    }

    // ── Setup helpers (idempotent) ──────────────────────────────────────

    function _setupPeer(Senders.Sender storage deployer, uint256 peerIdx) internal {
        NTTChainConfig memory peer = peerChains[peerIdx];
        address remoteManager = remoteNttManagers[peerIdx];
        address remoteXceiver = remoteTransceivers[peerIdx];
        uint256 inboundLimit = peerInboundLimits[peerIdx];

        console.log("  Peer: %s (wormhole chain %d)", peer.chainName, uint256(peer.wormholeChainId));
        console.log("    Remote NttManager:   %s", remoteManager);
        console.log("    Remote Transceiver:  %s", remoteXceiver);

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

    function _setupOutboundLimit(Senders.Sender storage deployer) internal {
        uint256 currentOutbound = _untrim(INTTManager(localNttManager).getOutboundLimitParams().limit);
        if (currentOutbound != myChain.outboundLimit) {
            console.log("  > Setting outbound limit to %d...", myChain.outboundLimit / 1e18);
            INTTManager(deployer.harness(localNttManager)).setOutboundLimit(myChain.outboundLimit);
        } else {
            console.log("  > Outbound limit already correct, skipping");
        }
    }

    function _setupBurnMintPermissions(Senders.Sender storage deployer) internal {
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

    function _setupOwnership(Senders.Sender storage deployer) internal {
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
            revert(string.concat("ConfigureNTT: unknown NTT_TOKEN: ", _tokenName));
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
        revert(string.concat("ConfigureNTT: current chain (", vm.toString(cid), ") not in config for ", config.tokenName));
    }

    function _findInboundLimit(NTTTokenConfig memory config, string memory fromChainName) internal pure returns (uint256) {
        for (uint256 i = 0; i < config.inboundLimits.length; i++) {
            if (keccak256(bytes(config.inboundLimits[i].fromChainName)) == keccak256(bytes(fromChainName))) {
                return config.inboundLimits[i].limit;
            }
        }
        revert(string.concat("ConfigureNTT: no inbound limit from chain '", fromChainName, "'"));
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
