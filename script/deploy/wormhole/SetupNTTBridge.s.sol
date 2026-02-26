// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {WormholeNTTConfig, NTTChainConfig} from "script/config/wormhole/WormholeNTTConfig.sol";
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
    function rateLimitDuration() external view returns (uint64);
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

/// @title SetupNTTBridge
/// @notice Generic, idempotent NTT bridge setup script. Reads a per-token
///         deployment JSON and configures the current chain's NTT Manager
///         and Transceiver with all its peers.
///
///         Works for both hub-spoke (locking) and burn-mint topologies —
///         the config's `isBurning` flag determines whether to grant
///         minter/burner permissions.
///
///         Usage (run once per token per chain):
///
///           TOKEN=USDm treb run SetupNTTBridge --network monad --debug
///           TOKEN=GBPm treb run SetupNTTBridge --network celo --debug
///
///         Mainnet/testnet is auto-detected from chain ID.
///
///         Adding a spoke: add the chain entry to the JSON, then run
///         on the new chain (full setup) and re-run on each existing chain
///         (only the new peer gets added; existing config is skipped).
contract SetupNTTBridge is AddressbookHelper {
    using Senders for Senders.Sender;

    // ── Loaded config (decomposed for storage compatibility) ──────────
    string internal tokenName;
    uint8 internal tokenDecimals;
    string internal ownerLabel;
    string[] internal chainNames;
    NTTChainConfig[] internal chains;
    uint256[] internal inboundLimits;
    uint64 internal rateLimitDuration;
    address internal owner;
    uint256 internal myIndex;

    function setUp() public {
        string memory token = vm.envString("TOKEN");
        (WormholeNTTConfig.ParsedConfig memory cfg, uint256[] memory _inboundLimits) = WormholeNTTConfig.load(token);

        // Copy scalar fields
        tokenName = cfg.tokenName;
        tokenDecimals = cfg.tokenDecimals;
        ownerLabel = cfg.ownerLabel;

        // Copy arrays element-by-element (Solidity cannot bulk-copy memory struct arrays to storage)
        for (uint256 i = 0; i < cfg.chains.length; i++) {
            chainNames.push(cfg.chainNames[i]);
            chains.push(cfg.chains[i]);
        }
        for (uint256 i = 0; i < _inboundLimits.length; i++) {
            inboundLimits.push(_inboundLimits[i]);
        }

        rateLimitDuration = uint64(vm.envOr("RATE_LIMIT_DURATION", uint256(86400)));
        owner = lookupAddressbook(ownerLabel);
        require(owner != address(0), string.concat(ownerLabel, " not found in addressbook"));
        myIndex = _findMyChain();

        NTTChainConfig memory me = chains[myIndex];
        console.log("=== SetupNTTBridge: %s on %s (chain %d) ===\n", tokenName, me.name, me.chainId);
        console.log("  NTT Manager:  %s", me.nttManager);
        console.log("  Transceiver:  %s", me.transceiver);
        console.log("  Token:        %s", me.token);
        console.log("  Mode:         %s", me.isBurning ? "burning" : "locking");
        console.log("  Owner:        %s\n", owner);
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        NTTChainConfig memory me = chains[myIndex];
        uint256 n = chains.length;

        // 1. Configure peers
        for (uint256 i = 0; i < n; i++) {
            if (i == myIndex) continue;
            _setupPeer(deployer, me, chains[i], inboundLimits[myIndex * n + i]);
        }

        // 2. Set outbound limit
        _setupOutboundLimit(deployer, me);

        // 3. Grant burn/mint permissions if this chain is in burning mode
        if (me.isBurning) {
            _setupBurnMintPermissions(deployer, me);
        }

        // 4. Transfer ownership and pauser to the configured owner
        _setupOwnership(deployer, me);

        console.log(unicode"=== %s setup on %s complete ===\n", tokenName, me.name);

        // 5. Verify everything
        _verifyAll(me);
    }

    // ── Setup helpers (idempotent) ──────────────────────────────────────

    function _setupPeer(
        Senders.Sender storage deployer,
        NTTChainConfig memory me,
        NTTChainConfig memory peer,
        uint256 inboundLimit
    ) internal {
        // NTT Manager peer
        NttManagerPeer memory existingPeer = INTTManager(me.nttManager).getPeer(peer.wormholeChainId);
        bytes32 expectedPeerManager = _toBytes32(peer.nttManager);
        if (existingPeer.peerAddress != expectedPeerManager) {
            console.log("> Setting NTT Manager peer for %s...", peer.name);
            INTTManager(deployer.harness(me.nttManager)).setPeer(
                peer.wormholeChainId,
                expectedPeerManager,
                tokenDecimals,
                inboundLimit
            );
        } else {
            console.log("> NTT Manager peer for %s already set, skipping", peer.name);
            // Peer already set, but check if inbound limit needs updating
            uint256 currentInbound = _untrim(INTTManager(me.nttManager).getInboundLimitParams(peer.wormholeChainId).limit);
            if (currentInbound != inboundLimit) {
                console.log("> Updating inbound limit from %s...", peer.name);
                INTTManager(deployer.harness(me.nttManager)).setInboundLimit(inboundLimit, peer.wormholeChainId);
            }
        }

        // Transceiver wormhole peer
        bytes32 expectedPeerTransceiver = _toBytes32(peer.transceiver);
        if (ITransceiver(me.transceiver).getWormholePeer(peer.wormholeChainId) != expectedPeerTransceiver) {
            console.log("> Setting Transceiver wormhole peer for %s...", peer.name);
            ITransceiver(deployer.harness(me.transceiver)).setWormholePeer(
                peer.wormholeChainId,
                expectedPeerTransceiver
            );
        } else {
            console.log("> Transceiver wormhole peer for %s already set, skipping", peer.name);
        }
    }

    function _setupOutboundLimit(
        Senders.Sender storage deployer,
        NTTChainConfig memory me
    ) internal {
        uint256 currentOutbound = _untrim(INTTManager(me.nttManager).getOutboundLimitParams().limit);
        if (currentOutbound != me.outboundLimit) {
            console.log("> Setting outbound limit...");
            INTTManager(deployer.harness(me.nttManager)).setOutboundLimit(me.outboundLimit);
        } else {
            console.log("> Outbound limit already correct, skipping");
        }
    }

    function _setupBurnMintPermissions(
        Senders.Sender storage deployer,
        NTTChainConfig memory me
    ) internal {
        if (!IStableTokenSpoke(me.token).isBurner(me.nttManager)) {
            console.log("> Granting NTT Manager burner permission...");
            IStableTokenSpoke(deployer.harness(me.token)).setBurner(me.nttManager, true);
        } else {
            console.log("> NTT Manager already has burner permission, skipping");
        }

        if (!IStableTokenSpoke(me.token).isMinter(me.nttManager)) {
            console.log("> Granting NTT Manager minter permission...");
            IStableTokenSpoke(deployer.harness(me.token)).setMinter(me.nttManager, true);
        } else {
            console.log("> NTT Manager already has minter permission, skipping");
        }
    }

    function _setupOwnership(
        Senders.Sender storage deployer,
        NTTChainConfig memory me
    ) internal {
        // NTT Manager ownership (cascades to all registered transceivers)
        if (IOwnable(me.nttManager).owner() != owner) {
            console.log("> Transferring NTT Manager ownership to %s...", owner);
            IOwnable(deployer.harness(me.nttManager)).transferOwnership(owner);
        } else {
            console.log("> NTT Manager already owned by %s, skipping", owner);
        }

        // Pauser capability does NOT cascade, must be set on each contract
        if (IPausable(me.nttManager).pauser() != owner) {
            console.log("> Transferring NTT Manager pauser to %s...", owner);
            IPausable(deployer.harness(me.nttManager)).transferPauserCapability(owner);
        } else {
            console.log("> NTT Manager pauser already %s, skipping", owner);
        }

        if (IPausable(me.transceiver).pauser() != owner) {
            console.log("> Transferring Transceiver pauser to %s...", owner);
            IPausable(deployer.harness(me.transceiver)).transferPauserCapability(owner);
        } else {
            console.log("> Transceiver pauser already %s, skipping", owner);
        }
    }

    // ── Verification ────────────────────────────────────────────────────

    function _verifyAll(NTTChainConfig memory me) internal view {
        console.log("== Verifying %s on %s ==", tokenName, me.name);
        uint256 n = chains.length;

        for (uint256 i = 0; i < n; i++) {
            if (i == myIndex) continue;
            NTTChainConfig memory peer = chains[i];
            _verifyNttManagerPeer(me.nttManager, peer.wormholeChainId, peer.nttManager);
            _verifyTransceiverPeer(me.transceiver, peer.wormholeChainId, peer.transceiver);
            _verifyInboundLimit(me.nttManager, peer.wormholeChainId, peer.name, inboundLimits[myIndex * n + i]);
        }

        _verifyOutboundLimit(me.nttManager, me.outboundLimit);
        _verifyRateLimitDuration(me.nttManager);

        if (me.isBurning) {
            _verifyBurnMintPermissions(me.token, me.nttManager);
        }

        _verifyOwnership(me.nttManager, me.transceiver, owner);

        console.log(unicode"== %s on %s verification passed ==\n", tokenName, me.name);
    }

    function _verifyNttManagerPeer(address manager, uint16 peerWormholeChainId, address expectedPeerManager) internal view {
        NttManagerPeer memory peer = INTTManager(manager).getPeer(peerWormholeChainId);
        require(peer.peerAddress == _toBytes32(expectedPeerManager), "NTT Manager peer address mismatch");
        require(peer.tokenDecimals == tokenDecimals, "NTT Manager peer decimals mismatch");
        console.log(" > NTT Manager peer for wormhole chain %d set correctly", peerWormholeChainId);
    }

    function _verifyTransceiverPeer(address transceiver_, uint16 peerWormholeChainId, address expectedPeer) internal view {
        require(
            ITransceiver(transceiver_).getWormholePeer(peerWormholeChainId) == _toBytes32(expectedPeer),
            "Transceiver peer address mismatch"
        );
        console.log(" > Transceiver peer for wormhole chain %d set correctly", peerWormholeChainId);
    }

    function _verifyInboundLimit(address manager, uint16 peerWormholeChainId, string memory peerName, uint256 expectedLimit) internal view {
        RateLimitParams memory params = INTTManager(manager).getInboundLimitParams(peerWormholeChainId);
        require(_untrim(params.limit) == expectedLimit, string.concat("Inbound limit mismatch for ", peerName));
        console.log(" > Inbound limit from %s: %d", peerName, expectedLimit / 1e18);
    }

    function _verifyOutboundLimit(address manager, uint256 expectedLimit) internal view {
        RateLimitParams memory params = INTTManager(manager).getOutboundLimitParams();
        require(_untrim(params.limit) == expectedLimit, "Outbound limit mismatch");
        console.log(" > Outbound limit: %d", expectedLimit / 1e18);
    }

    function _verifyRateLimitDuration(address manager) internal view {
        uint64 duration = INTTManager(manager).rateLimitDuration();
        require(duration == rateLimitDuration, "Rate limit duration mismatch");
        console.log(" > Rate limit duration: %d seconds", duration);
    }

    function _verifyBurnMintPermissions(address token, address manager) internal view {
        require(IStableTokenSpoke(token).isMinter(manager), "NTT Manager is not a minter");
        require(IStableTokenSpoke(token).isBurner(manager), "NTT Manager is not a burner");
        console.log(" > NTT Manager has minter and burner roles");
    }

    function _verifyOwnership(address manager, address transceiver_, address expectedOwner) internal view {
        require(IOwnable(manager).owner() == expectedOwner, "NTT Manager owner mismatch");
        require(IOwnable(transceiver_).owner() == expectedOwner, "Transceiver owner mismatch");
        require(IPausable(manager).pauser() == expectedOwner, "NTT Manager pauser mismatch");
        require(IPausable(transceiver_).pauser() == expectedOwner, "Transceiver pauser mismatch");
        console.log(" > Ownership and pauser set to %s", expectedOwner);
    }

    // ── Pure helpers ────────────────────────────────────────────────────

    function _findMyChain() internal view returns (uint256) {
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i].chainId == block.chainid) return i;
        }
        revert(string.concat("Current chain (", vm.toString(block.chainid), ") not found in NTT config"));
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /// @dev Decode a TrimmedAmount (uint72) back to a full-precision value.
    ///      TrimmedAmount packs: (amount << 8) | trimmedDecimals
    ///      See: https://github.com/wormhole-foundation/native-token-transfers/blob/main/evm/src/libraries/TrimmedAmount.sol
    function _untrim(uint72 packed) internal view returns (uint256) {
        uint8 decimals = uint8(packed & 0xFF);
        uint64 amount = uint64(packed >> 8);
        uint8 td = tokenDecimals;
        if (decimals == td) return uint256(amount);
        if (decimals < td) return uint256(amount) * 10 ** (td - decimals);
        return uint256(amount) / 10 ** (decimals - td);
    }
}
