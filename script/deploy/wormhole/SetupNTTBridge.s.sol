// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

// ── Wormhole NTT interfaces ─────────────────────────────────────────────────

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

// ── Config structs ──────────────────────────────────────────────────────────

struct ChainConfig {
    string name;
    uint256 chainId;
    uint16 wormholeChainId;
    address nttManager;
    address transceiver;
    address token;
    bool isBurning;
    uint256 outboundLimit;
}

// ── Script ──────────────────────────────────────────────────────────────────

/// @title SetupNTTBridge
/// @notice Generic, idempotent NTT bridge setup script. Reads a per-token
///         deployment JSON and configures the current chain's NTT Manager
///         and Transceiver with all its peers.
///
///         Works for both hub-spoke (locking) and burn-mint topologies —
///         the JSON's `isBurning` flag determines whether to grant
///         minter/burner permissions.
///
///         The JSON extends the Wormhole NTT CLI output format with
///         additional fields: chainId, wormholeChainId, isBurning,
///         tokenName, tokenDecimals, ownerLabel.
///
///         Usage (run once per token per chain):
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/USDm.json \
///             treb run SetupNTTBridge --network monad --debug
///
///           WORMHOLE_DEPLOYMENT_FILE=script/deploy/wormhole/configs/GBPm.json \
///             treb run SetupNTTBridge --network celo --debug
///
///         Adding a spoke: add the chain entry to the JSON, then run
///         on the new chain (full setup) and re-run on each existing chain
///         (only the new peer gets added; existing config is skipped).
contract SetupNTTBridge is AddressbookHelper {
    using Senders for Senders.Sender;

    // ── Parsed config ───────────────────────────────────────────────────
    string internal json;
    string internal tokenName;
    uint8 internal tokenDecimals;
    uint64 internal rateLimitDuration;
    address internal owner;

    string[] internal chainNames;
    ChainConfig[] internal chains;
    uint256 internal myIndex;

    // Inbound limits: inboundLimits[myIndex][peerIndex] = limit from peer
    mapping(uint256 => mapping(uint256 => uint256)) internal inboundLimits;

    function setUp() public {
        _loadConfig();
        myIndex = _findMyChain();

        ChainConfig memory me = chains[myIndex];
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
        ChainConfig memory me = chains[myIndex];

        // 1. Configure peers
        for (uint256 i = 0; i < chains.length; i++) {
            if (i == myIndex) continue;
            _setupPeer(deployer, me, chains[i], inboundLimits[myIndex][i]);
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

    // ── Config loading ──────────────────────────────────────────────────

    function _loadConfig() internal {
        string memory path = vm.envString("WORMHOLE_DEPLOYMENT_FILE");
        json = vm.readFile(path);

        tokenName = vm.parseJsonString(json, ".tokenName");
        tokenDecimals = uint8(vm.parseJsonUint(json, ".tokenDecimals"));
        rateLimitDuration = uint64(vm.envOr("RATE_LIMIT_DURATION", uint256(86400)));

        string memory ownerLabel = vm.parseJsonString(json, ".ownerLabel");
        owner = lookupAddressbook(ownerLabel);
        require(owner != address(0), string.concat(ownerLabel, " not found in addressbook"));

        // Enumerate chains dynamically
        chainNames = vm.parseJsonKeys(json, ".chains");
        for (uint256 i = 0; i < chainNames.length; i++) {
            string memory c = chainNames[i];
            string memory base = string.concat(".chains.", c);

            chains.push(ChainConfig({
                name: c,
                chainId: vm.parseJsonUint(json, string.concat(base, ".chainId")),
                wormholeChainId: uint16(vm.parseJsonUint(json, string.concat(base, ".wormholeChainId"))),
                nttManager: vm.parseJsonAddress(json, string.concat(base, ".manager")),
                transceiver: vm.parseJsonAddress(json, string.concat(base, ".transceivers.wormhole.address")),
                token: vm.parseJsonAddress(json, string.concat(base, ".token")),
                isBurning: vm.parseJsonBool(json, string.concat(base, ".isBurning")),
                outboundLimit: vm.parseUint(vm.parseJsonString(json, string.concat(base, ".limits.outbound")))
            }));

            // Parse inbound limits from each peer for this chain
            for (uint256 j = 0; j < chainNames.length; j++) {
                if (j == i) continue;
                string memory inboundPath = string.concat(base, ".limits.inbound.", chainNames[j]);
                inboundLimits[i][j] = vm.parseUint(vm.parseJsonString(json, inboundPath));
            }
        }

        // Validate
        for (uint256 i = 0; i < chains.length; i++) {
            ChainConfig memory c = chains[i];
            require(c.nttManager != address(0), string.concat(c.name, ": manager is zero address"));
            require(c.transceiver != address(0), string.concat(c.name, ": transceiver is zero address"));
            require(c.token != address(0), string.concat(c.name, ": token is zero address"));
        }

        console.log("Loaded config for %s from %s (%d chains)", tokenName, path, chains.length);
    }

    // ── Setup helpers (idempotent) ──────────────────────────────────────

    function _setupPeer(
        Senders.Sender storage deployer,
        ChainConfig memory me,
        ChainConfig memory peer,
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
        ChainConfig memory me
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
        ChainConfig memory me
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
        ChainConfig memory me
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

    function _verifyAll(ChainConfig memory me) internal view {
        console.log("== Verifying %s on %s ==", tokenName, me.name);

        for (uint256 i = 0; i < chains.length; i++) {
            if (i == myIndex) continue;
            ChainConfig memory peer = chains[i];
            _verifyNttManagerPeer(me.nttManager, peer.wormholeChainId, peer.nttManager);
            _verifyTransceiverPeer(me.transceiver, peer.wormholeChainId, peer.transceiver);
            _verifyInboundLimit(me.nttManager, peer.wormholeChainId, peer.name, inboundLimits[myIndex][i]);
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

    function _verifyTransceiverPeer(address transceiver, uint16 peerWormholeChainId, address expectedPeer) internal view {
        require(
            ITransceiver(transceiver).getWormholePeer(peerWormholeChainId) == _toBytes32(expectedPeer),
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

    function _verifyOwnership(address manager, address transceiver, address expectedOwner) internal view {
        require(IOwnable(manager).owner() == expectedOwner, "NTT Manager owner mismatch");
        require(IOwnable(transceiver).owner() == expectedOwner, "Transceiver owner mismatch");
        require(IPausable(manager).pauser() == expectedOwner, "NTT Manager pauser mismatch");
        require(IPausable(transceiver).pauser() == expectedOwner, "Transceiver pauser mismatch");
        console.log(" > Ownership and pauser set to %s", expectedOwner);
    }

    // ── Pure helpers ────────────────────────────────────────────────────

    function _findMyChain() internal view returns (uint256) {
        uint256 cid;
        assembly {
            cid := chainid()
        }
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i].chainId == cid) return i;
        }
        revert(string.concat("Current chain (", vm.toString(cid), ") not found in NTT config"));
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
        if (decimals == tokenDecimals) return uint256(amount);
        if (decimals < tokenDecimals) return uint256(amount) * 10 ** (tokenDecimals - decimals);
        return uint256(amount) / 10 ** (decimals - tokenDecimals);
    }
}
