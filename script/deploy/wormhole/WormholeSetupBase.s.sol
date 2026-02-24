// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {console2 as console} from "forge-std/console2.sol";

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


/// @title WormholeSetupBase
/// @notice Shared base for Wormhole NTT bridge setup scripts.
///         Provides chain constants, shared config loaded from a Wormhole NTT
///         deployment JSON, helpers, and verification utilities.
///
///         Required env var:
///           WORMHOLE_DEPLOYMENT_FILE - path to a Wormhole NTT deployment JSON
///                             (e.g. "script/deploy/wormhole/configs/USDm.json")
///
///         The JSON is the standard output of the Wormhole NTT CLI and must
///         contain "Celo" and "Monad" entries under ".chains".
abstract contract WormholeSetupBase is AddressbookHelper {
    // ── Chain constants ──────────────────────────────────────────────────
    // Celo
    uint256 public constant CELO_CHAIN_ID = 42220;
    uint16 public constant CELO_WORMHOLE_CHAIN_ID = 14;

    // Monad
    uint256 public constant MONAD_CHAIN_ID = 143;
    uint16 public constant MONAD_WORMHOLE_CHAIN_ID = 48;

    // Token decimals (same on both chains)
    uint8 public constant TOKEN_DECIMALS = 18;

    // ── Shared config (populated by _loadConfig from deployment JSON) ────
    address public celoNttManager;
    address public celoTransceiver;
    uint256 public celoInboundLimit;
    uint256 public celoOutboundLimit;
    address public celoV3Token;

    address public monadNttManager;
    address public monadTransceiver;
    uint256 public monadInboundLimit;
    uint256 public monadOutboundLimit;
    address public monadSpokeToken;

    address public migrationMultisig;
    uint64 public expectedRateLimitDuration;

    // ── Config loading ───────────────────────────────────────────────────

    function _loadConfig() internal {
        string memory path = vm.envString("WORMHOLE_DEPLOYMENT_FILE");
        string memory json = vm.readFile(path);

        celoNttManager = vm.parseJsonAddress(json, ".chains.Celo.manager");
        celoTransceiver = vm.parseJsonAddress(json, ".chains.Celo.transceivers.wormhole.address");
        celoV3Token = vm.parseJsonAddress(json, ".chains.Celo.token");
        celoInboundLimit = vm.parseUint(vm.parseJsonString(json, ".chains.Celo.limits.inbound.Monad"));
        celoOutboundLimit = vm.parseUint(vm.parseJsonString(json, ".chains.Celo.limits.outbound"));

        monadNttManager = vm.parseJsonAddress(json, ".chains.Monad.manager");
        monadTransceiver = vm.parseJsonAddress(json, ".chains.Monad.transceivers.wormhole.address");
        monadSpokeToken = vm.parseJsonAddress(json, ".chains.Monad.token");
        monadInboundLimit = vm.parseUint(vm.parseJsonString(json, ".chains.Monad.limits.inbound.Celo"));
        monadOutboundLimit = vm.parseUint(vm.parseJsonString(json, ".chains.Monad.limits.outbound"));

        require(celoNttManager != address(0), "Celo manager not found in deployment file");
        require(celoTransceiver != address(0), "Celo transceiver not found in deployment file");
        require(celoV3Token != address(0), "Celo token not found in deployment file");
        require(celoInboundLimit > 0, "Celo inbound limit not found in deployment file");
        require(celoOutboundLimit > 0, "Celo outbound limit not found in deployment file");

        require(monadNttManager != address(0), "Monad manager not found in deployment file");
        require(monadTransceiver != address(0), "Monad transceiver not found in deployment file");
        require(monadSpokeToken != address(0), "Monad token not found in deployment file");
        require(monadInboundLimit > 0, "Monad inbound limit not found in deployment file");
        require(monadOutboundLimit > 0, "Monad outbound limit not found in deployment file");

        migrationMultisig = lookupAddressbook("MigrationMultisig");
        require(migrationMultisig != address(0), "MigrationMultisig not found in addressbook");

        // This needs to be set during the contracts deployment which happens
        // outside of treb, so we can verify that it matches the expected value.
        expectedRateLimitDuration = uint64(vm.envOr("RATE_LIMIT_DURATION", uint256(86400)));

        console.log("Loaded config from %s", path);
        console.log("  Celo:  manager=%s transceiver=%s token=%s", celoNttManager, celoTransceiver, celoV3Token);
        console.log("  Monad: manager=%s transceiver=%s token=%s\n", monadNttManager, monadTransceiver, monadSpokeToken);
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
        console.log("Verifying NTT Manager peer on %s", manager);
        NttManagerPeer memory peer = INTTManager(manager).getPeer(peerWormholeChainId);
        require(
            peer.peerAddress == _toBytes32(expectedPeerManager),
            "NTT Manager peer address mismatch"
        );
        require(peer.tokenDecimals == TOKEN_DECIMALS, "NTT Manager peer decimals mismatch");
        console.log(" > Peer set to %s with %d decimals\n", expectedPeerManager, TOKEN_DECIMALS);
    }

    function _verifyTransceiverPeer(
        address transceiver,
        uint16 peerWormholeChainId,
        address expectedPeerTransceiver
    ) internal view {
        console.log("Verifying Transceiver peer on %s", transceiver);
        require(
            ITransceiver(transceiver).getWormholePeer(peerWormholeChainId) == _toBytes32(expectedPeerTransceiver),
            "Transceiver peer address mismatch"
        );
        console.log(" > Wormhole peer set to %s\n", expectedPeerTransceiver);
    }

    function _verifyOutboundLimit(address manager, uint256 expectedLimit) internal view {
        console.log("Verifying outbound limit on %s", manager);
        RateLimitParams memory params = INTTManager(manager).getOutboundLimitParams();
        require(_unmask(params.limit) == expectedLimit, "Outbound limit mismatch");
        console.log(" > Outbound limit set to %d\n", expectedLimit / 1e18);
    }

    function _verifyRateLimitDuration(address manager) internal view {
        console.log("Verifying rate limit duration on %s", manager);
        uint64 duration = INTTManager(manager).rateLimitDuration();
        require(duration == expectedRateLimitDuration, "Rate limit duration mismatch");
        console.log(" > Rate limit duration is %d seconds\n", duration);
    }

    function _verifyOwnership(address manager, address transceiver, address expectedOwner) internal view {
        console.log("Verifying ownership of NTT Manager %s", manager);
        require(IOwnable(manager).owner() == expectedOwner, "NTT Manager owner mismatch");
        console.log(" > Owner is %s\n", expectedOwner);

        console.log("Verifying ownership of Transceiver %s", transceiver);
        require(IOwnable(transceiver).owner() == expectedOwner, "Transceiver owner mismatch");
        console.log(" > Owner is %s\n", expectedOwner);

        console.log("Verifying pauser of NTT Manager %s", manager);
        require(IPausable(manager).pauser() == expectedOwner, "NTT Manager pauser mismatch");
        console.log(" > Pauser is %s\n", expectedOwner);

        console.log("Verifying pauser of Transceiver %s", transceiver);
        require(IPausable(transceiver).pauser() == expectedOwner, "Transceiver pauser mismatch");
        console.log(" > Pauser is %s\n", expectedOwner);
    }
}
