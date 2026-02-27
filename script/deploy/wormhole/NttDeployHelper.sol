// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {NttManager} from "mento-stabletoken-ntt/src/NttManager/NttManager.sol";
import {
    WormholeTransceiver
} from "mento-stabletoken-ntt/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @dev Minimal interface for PausedOwnable.transferPauserCapability.
interface IPausable {
    function transferPauserCapability(address newPauser) external;
}

/// @title NttDeployHelper
/// @notice Deployed via CREATE3 to bootstrap NttManager + WormholeTransceiver
///         ERC1967 proxies in a single transaction.
///
/// @dev Why a helper contract?
///      NTT contracts store an immutable `deployer` (set to msg.sender in the
///      implementation constructor) and verify `msg.sender == deployer` during
///      `initialize()`. CREATE3 uses an intermediate contract, so the address
///      that deploys the implementation differs from the address that later
///      calls `initialize()`. By performing all deployments AND initialization
///      inside this helper's constructor, msg.sender is consistent (= this
///      contract) for every step.
///
///      After deployment, ownership and pauser capabilities are transferred to
///      `initialOwner` so the treb deployer can manage the contracts in
///      subsequent scripts (e.g., ConfigureNTT).
contract NttDeployHelper {
    // ── Deployed addresses (immutables, readable after deployment) ────────
    address public immutable nttManagerProxy;
    address public immutable nttManagerImpl;
    address public immutable transceiverProxy;
    address public immutable transceiverImpl;

    // ── Constants ─────────────────────────────────────────────────────────
    uint64 constant RATE_LIMIT_DURATION = 86400; // 24 hours

    constructor(
        address token,
        IManagerBase.Mode mode,
        uint16 wormholeChainId,
        address wormholeCoreBridge,
        uint8 consistencyLevel,
        address initialOwner
    ) {
        // 1. Deploy NttManager implementation
        NttManager _nttManagerImpl = new NttManager(
            token,
            mode,
            wormholeChainId,
            RATE_LIMIT_DURATION,
            false // don't skip rate limiting
        );
        nttManagerImpl = address(_nttManagerImpl);

        // 2. Deploy NttManager ERC1967 proxy (empty init data — initialize separately)
        address _nttManagerProxy = address(new ERC1967Proxy(address(_nttManagerImpl), ""));
        nttManagerProxy = _nttManagerProxy;

        // 3. Initialize NttManager (msg.sender == address(this) == deployer ✓)
        NttManager(_nttManagerProxy).initialize();

        // 4. Deploy WormholeTransceiver implementation
        WormholeTransceiver _transceiverImpl = new WormholeTransceiver(
            _nttManagerProxy,
            wormholeCoreBridge,
            consistencyLevel,
            0, // customConsistencyLevel
            0, // additionalBlocks
            address(0) // customConsistencyLevelAddress
        );
        transceiverImpl = address(_transceiverImpl);

        // 5. Deploy WormholeTransceiver ERC1967 proxy
        address _transceiverProxy = address(new ERC1967Proxy(address(_transceiverImpl), ""));
        transceiverProxy = _transceiverProxy;

        // 6. Initialize WormholeTransceiver
        //    Note: This publishes a Wormhole message. Requires msg.value == messageFee.
        //    On chains where messageFee == 0 (e.g., Celo), msg.value=0 works.
        WormholeTransceiver(_transceiverProxy).initialize();

        // 7. Register transceiver and set threshold
        NttManager(_nttManagerProxy).setTransceiver(_transceiverProxy);
        NttManager(_nttManagerProxy).setThreshold(1);

        // 8. Transfer pauser capabilities (must happen BEFORE ownership transfer)
        IPausable(_nttManagerProxy).transferPauserCapability(initialOwner);
        IPausable(_transceiverProxy).transferPauserCapability(initialOwner);

        // 9. Transfer ownership (cascades to registered transceivers)
        NttManager(_nttManagerProxy).transferOwnership(initialOwner);
    }
}
