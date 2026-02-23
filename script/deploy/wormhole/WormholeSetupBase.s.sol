// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2 as console} from "forge-std/Script.sol";

/// @dev NTT Manager peer info returned by getPeer()
struct NttManagerPeer {
    bytes32 peerAddress;
    uint8 tokenDecimals;
}

/// @dev Rate limit parameters returned by getInboundLimitParams() / getOutboundLimitParams()
struct RateLimitParams {
    uint72 limit; // TrimmedAmount
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
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

interface ITransceiver {
    function setWormholePeer(uint16 chainId, bytes32 peerContract) external payable;
    function getWormholePeer(uint16 chainId) external view returns (bytes32);
    function owner() external view returns (address);
}


/// @title WormholeSetupBase
/// @notice Shared base for Wormhole NTT bridge setup scripts.
///         Provides chain constants, shared config loaded from env, helpers,
///         and verification utilities.
///
///         Common env vars (loaded by _loadConfig):
///           CELO_NTT_MANAGER, CELO_TRANSCEIVER, CELO_INBOUND_LIMIT, CELO_V3_TOKEN
///           MONAD_NTT_MANAGER, MONAD_TRANSCEIVER, MONAD_INBOUND_LIMIT, MONAD_SPOKE_TOKEN
abstract contract WormholeSetupBase is Script {
    // ── Chain constants ──────────────────────────────────────────────────
    // Celo
    uint256 public constant CELO_CHAIN_ID = 42220;
    uint16 public constant CELO_WORMHOLE_CHAIN_ID = 14;

    // Monad
    uint256 public constant MONAD_CHAIN_ID = 143;
    uint16 public constant MONAD_WORMHOLE_CHAIN_ID = 48;

    // Token decimals (same on both chains)
    uint8 public constant TOKEN_DECIMALS = 18;

    // ── Shared config (populated by _loadConfig from env) ────────────────
    address public celoNttManager;
    address public celoTransceiver;
    uint256 public celoInboundLimit;
    address public celoV3Token;

    address public monadNttManager;
    address public monadTransceiver;
    uint256 public monadInboundLimit;
    address public monadSpokeToken;

    // ── Config loading ───────────────────────────────────────────────────

    function _loadConfig() internal {
        celoNttManager = vm.envAddress("CELO_NTT_MANAGER");
        celoTransceiver = vm.envAddress("CELO_TRANSCEIVER");
        celoInboundLimit = vm.envUint("CELO_INBOUND_LIMIT");
        celoV3Token = vm.envAddress("CELO_V3_TOKEN");

        monadNttManager = vm.envAddress("MONAD_NTT_MANAGER");
        monadTransceiver = vm.envAddress("MONAD_TRANSCEIVER");
        monadInboundLimit = vm.envUint("MONAD_INBOUND_LIMIT");
        monadSpokeToken = vm.envAddress("MONAD_SPOKE_TOKEN");

        require(celoNttManager != address(0), "CELO_NTT_MANAGER not set");
        require(celoTransceiver != address(0), "CELO_TRANSCEIVER not set");
        require(celoInboundLimit > 0, "CELO_INBOUND_LIMIT not set");
        require(celoV3Token != address(0), "CELO_V3_TOKEN not set");

        require(monadNttManager != address(0), "MONAD_NTT_MANAGER not set");
        require(monadTransceiver != address(0), "MONAD_TRANSCEIVER not set");
        require(monadInboundLimit > 0, "MONAD_INBOUND_LIMIT not set");
        require(monadSpokeToken != address(0), "MONAD_SPOKE_TOKEN not set");
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    function _chainId() internal view returns (uint256 cid) {
        assembly {
            cid := chainid()
        }
    }

    function isCelo() internal view returns (bool) {
        return _chainId() == CELO_CHAIN_ID;
    }

    function isMonad() internal view returns (bool) {
        return _chainId() == MONAD_CHAIN_ID;
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /// @dev Decode a TrimmedAmount stored as uint72 back to the full-precision value.
    ///      Assumes 18-decimal tokens (SCALE = 1e10, TRIMMED_DECIMALS = 8).
    ///      See: https://github.com/wormhole-foundation/native-token-transfers/blob/main/evm/src/libraries/TrimmedAmount.sol
    function _unmask(uint72 value) internal pure returns (uint256) {
        uint256 SCALE = 1e10;
        uint256 TRIMMED_DECIMALS = 8;
        uint256 v = uint256(value);
        return ((v & ~TRIMMED_DECIMALS) >> 8) * SCALE;
    }

    // ── Verification helpers ─────────────────────────────────────────────

    function _verifyNttManagerPeer(
        address manager,
        uint16 peerWormholeChainId,
        address expectedPeerManager
    ) internal view {
        console.log("  Verifying NTT Manager peer on %s", manager);
        NttManagerPeer memory peer = INTTManager(manager).getPeer(peerWormholeChainId);
        require(
            peer.peerAddress == _toBytes32(expectedPeerManager),
            "NTT Manager peer address mismatch"
        );
        require(peer.tokenDecimals == TOKEN_DECIMALS, "NTT Manager peer decimals mismatch");
        console.log("  -> Peer set to %s with %d decimals", expectedPeerManager, TOKEN_DECIMALS);
    }

    function _verifyTransceiverPeer(
        address transceiver,
        uint16 peerWormholeChainId,
        address expectedPeerTransceiver
    ) internal view {
        console.log("  Verifying Transceiver peer on %s", transceiver);
        require(
            ITransceiver(transceiver).getWormholePeer(peerWormholeChainId) == _toBytes32(expectedPeerTransceiver),
            "Transceiver peer address mismatch"
        );
        console.log("  -> Wormhole peer set to %s", expectedPeerTransceiver);
    }
}
