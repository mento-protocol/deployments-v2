// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

import {IManagerBase} from "mento-stabletoken-ntt/src/interfaces/IManagerBase.sol";
import {INttManager} from "mento-stabletoken-ntt/src/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "mento-stabletoken-ntt/src/interfaces/IWormholeTransceiver.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {INttToken} from "mento-stabletoken-ntt/src/interfaces/INttToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface INttDeployHelper {
    function nttManagerProxy() external view returns (address);
    function transceiverProxy() external view returns (address);
}

/// @title USDmBridge — Celo <> Monad NTT bridge fork test
/// @notice Proves a USDm transfer initiated on Celo can be delivered on Monad
///         against the *live, deployed* NTT contracts — i.e. that ConfigureNTT
///         wired up the peers, threshold, and mint permissions correctly.
///
/// @dev Strategy: forks both chains in one test process.
///      1. On Celo: do a REAL nttManager.transfer(), capturing the Wormhole
///         core-bridge `LogMessagePublished` event. Its `payload` is exactly
///         the bytes a guardian would sign into a VAA.
///      2. On Monad: mock `parseAndVerifyVM` (the ONLY crypto gate) to return
///         a VM we build from that payload, then call the real
///         transceiver.receiveMessage(). Everything else it checks (peer
///         addresses, threshold, minter role) is genuine on-chain state, so a
///         missed/incorrect ConfigureNTT surfaces as a revert here.
///
///      Run:  forge test --mc USDmBridge -vvv
contract USDmBridgeTest is Test {
    // ── Hardcoded RPCs (simplest thing that works) ─────────────────────
    // RPCs: prefer env (private, reliable), fall back to public endpoints.
    function _celoRpc() internal view returns (string memory) {
        return vm.envOr("CELO_RPC_URL", string("https://forno.celo.org"));
    }

    function _monadRpc() internal view returns (string memory) {
        return vm.envOr("MONAD_RPC_URL", string("https://rpc.monad.xyz"));
    }

    // Encoded transceiver instructions with count=0 (single 0x00 byte).
    // Empty `bytes` reverts in parseTransceiverInstructions; count-prefix is required.
    bytes constant EMPTY_INSTRUCTIONS = hex"00";

    // NttDeployHelper is deployed at the same CREATE3 address on both chains.
    address constant NTT_HELPER = 0x37316334108C816f9862baB52347A0aab7551127;

    // Wormhole core bridge per chain (from .treb/addressbook.json).
    address constant CELO_CORE_BRIDGE = 0xa321448d90d4e5b0A732867c18eA198e75CAC48E;
    address constant MONAD_CORE_BRIDGE = 0x194B123c5E96B9b2E49763619985790Dc241CAC0;

    // Wormhole chain IDs (from NTTConfig.sol).
    uint16 constant CELO_WH_ID = 14;
    uint16 constant MONAD_WH_ID = 48;

    uint256 celoFork;
    uint256 monadFork;

    // Celo (source) contracts
    INttManager celoManager;
    address celoTransceiver;
    IERC20 celoToken;

    // Monad (destination) contracts
    INttManager monadManager;
    IWormholeTransceiver monadTransceiver;
    IERC20 monadToken;

    function setUp() public {
        celoFork = vm.createFork(_celoRpc());
        monadFork = vm.createFork(_monadRpc());

        vm.selectFork(celoFork);
        celoManager = INttManager(INttDeployHelper(NTT_HELPER).nttManagerProxy());
        celoTransceiver = INttDeployHelper(NTT_HELPER).transceiverProxy();
        celoToken = IERC20(celoManager.token());

        vm.selectFork(monadFork);
        monadManager = INttManager(INttDeployHelper(NTT_HELPER).nttManagerProxy());
        monadTransceiver = IWormholeTransceiver(INttDeployHelper(NTT_HELPER).transceiverProxy());
        monadToken = IERC20(monadManager.token());

        console.log("=========================================================");
        console.log(" NTT bridge setup: USDm  Celo (14) -> Monad (48)");
        console.log("=========================================================");
        console.log(" [celo]  NttManager:   %s", address(celoManager));
        console.log(" [celo]  Transceiver:  %s", celoTransceiver);
        console.log(" [celo]  USDm token:   %s", address(celoToken));
        console.log(" [monad] NttManager:   %s", address(monadManager));
        console.log(" [monad] Transceiver:  %s", address(monadTransceiver));
        console.log(" [monad] USDm token:   %s", address(monadToken));
        console.log("");
    }

    function test_bridge_USDm_celo_to_monad() public {
        uint256 amount = 100e18;
        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        console.log("Bridging %s USDm  sender %s -> recipient %s", _fmt(amount), sender, recipient);
        console.log("");

        // ── 1. SOURCE (Celo): real outbound transfer ───────────────────
        vm.selectFork(celoFork);
        console.log("--- STEP 1: source chain (Celo) ------------------------");

        // Fund the sender by minting via the NttManager's minter authority.
        // The NttManager itself is a minter (burn/mint mode), so prank as it.
        vm.prank(address(celoManager));
        INttToken(address(celoToken)).mint(sender, amount);
        assertEq(celoToken.balanceOf(sender), amount, "sender not funded");

        uint256 celoSupplyBefore = celoToken.totalSupply();
        console.log("  before: sender balance      = %s USDm", _fmt(celoToken.balanceOf(sender)));
        console.log("  before: celo total supply   = %s USDm", _fmt(celoSupplyBefore));

        // Quote the delivery fee (manual relaying → typically the wormhole msg fee).
        (, uint256 fee) = celoManager.quoteDeliveryPrice(MONAD_WH_ID, EMPTY_INSTRUCTIONS);
        vm.deal(sender, fee);
        console.log("  quoted wormhole delivery fee = %s wei", fee);

        vm.startPrank(sender);
        celoToken.approve(address(celoManager), amount);
        vm.recordLogs();
        celoManager.transfer{value: fee}(amount, MONAD_WH_ID, _toBytes32(recipient));
        vm.stopPrank();

        uint256 celoSupplyAfter = celoToken.totalSupply();
        console.log("  after:  sender balance      = %s USDm", _fmt(celoToken.balanceOf(sender)));
        console.log("  after:  celo total supply   = %s USDm", _fmt(celoSupplyAfter));
        console.log("  => burned on celo           = %s USDm", _fmt(celoSupplyBefore - celoSupplyAfter));

        // USDm is burn-mint on Celo → supply should drop by `amount`.
        assertEq(celoSupplyAfter, celoSupplyBefore - amount, "celo supply not burned");

        // Extract the Wormhole message payload emitted by the core bridge.
        bytes memory whPayload = _captureWormholePayload(CELO_CORE_BRIDGE);
        assertGt(whPayload.length, 0, "no wormhole message published");
        console.log("  captured wormhole message   = %s bytes", whPayload.length);
        console.log("");

        // ── 2. DESTINATION (Monad): deliver via faked VAA ──────────────
        vm.selectFork(monadFork);
        console.log("--- STEP 2: destination chain (Monad) ------------------");

        uint256 recipientBefore = monadToken.balanceOf(recipient);
        uint256 monadSupplyBefore = monadToken.totalSupply();
        console.log("  before: recipient balance   = %s USDm", _fmt(recipientBefore));
        console.log("  before: monad total supply  = %s USDm", _fmt(monadSupplyBefore));

        // Build the VM the guardians would have produced.
        IWormhole.VM memory vaa = _buildVM({
            emitterChainId: CELO_WH_ID,
            emitterAddress: _toBytes32(celoTransceiver),
            payload: whPayload,
            uniqueHash: keccak256(abi.encode("celo->monad", block.timestamp, whPayload))
        });

        // Mock the ONLY crypto gate: parseAndVerifyVM on Monad's core bridge.
        vm.mockCall(
            MONAD_CORE_BRIDGE,
            abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector),
            abi.encode(vaa, true, "")
        );
        console.log("  mocked parseAndVerifyVM (guardian signatures bypassed)");

        // Anyone can relay a valid VAA. Deliver it.
        console.log("  calling transceiver.receiveMessage() ...");
        monadTransceiver.receiveMessage(_encodeVaaPlaceholder(vaa));

        vm.clearMockedCalls();

        uint256 recipientAfter = monadToken.balanceOf(recipient);
        uint256 monadSupplyAfter = monadToken.totalSupply();
        console.log("  after:  recipient balance   = %s USDm", _fmt(recipientAfter));
        console.log("  after:  monad total supply  = %s USDm", _fmt(monadSupplyAfter));
        console.log("  => minted on monad          = %s USDm", _fmt(recipientAfter - recipientBefore));
        console.log("");

        // ── 3. Assert the mint landed on Monad ─────────────────────────
        assertEq(recipientAfter - recipientBefore, amount, "recipient not minted on monad");

        console.log("--- RESULT ---------------------------------------------");
        console.log("  bridged %s USDm: celo supply -%s, monad recipient +%s",
            _fmt(amount), _fmt(celoSupplyBefore - celoSupplyAfter), _fmt(recipientAfter - recipientBefore));
        console.log("  bridge is correctly configured (peers + mint role OK)");
    }

    // ── Helpers ────────────────────────────────────────────────────────

    /// @dev Scans recorded logs for the core bridge's LogMessagePublished and
    ///      returns its `payload` field (the transceiver-encoded message).
    ///      LogMessagePublished(address indexed sender, uint64 sequence,
    ///                          uint32 nonce, bytes payload, uint8 consistencyLevel)
    function _captureWormholePayload(address coreBridge) internal returns (bytes memory) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("LogMessagePublished(address,uint64,uint32,bytes,uint8)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == coreBridge && logs[i].topics[0] == topic) {
                // Non-indexed args: (uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel)
                (,, bytes memory payload,) = abi.decode(logs[i].data, (uint64, uint32, bytes, uint8));
                return payload;
            }
        }
        return "";
    }

    function _buildVM(
        uint16 emitterChainId,
        bytes32 emitterAddress,
        bytes memory payload,
        bytes32 uniqueHash
    ) internal pure returns (IWormhole.VM memory vaa) {
        vaa.version = 1;
        vaa.timestamp = 0;
        vaa.nonce = 0;
        vaa.emitterChainId = emitterChainId;
        vaa.emitterAddress = emitterAddress;
        vaa.sequence = 0;
        vaa.consistencyLevel = 202;
        vaa.payload = payload;
        vaa.guardianSetIndex = 0;
        vaa.signatures = new IWormhole.Signature[](0);
        vaa.hash = uniqueHash;
    }

    /// @dev receiveMessage takes the encoded VAA bytes, but since we mock
    ///      parseAndVerifyVM the actual bytes are never parsed — any non-empty
    ///      blob works. We pass the payload so failures are still legible.
    function _encodeVaaPlaceholder(IWormhole.VM memory vaa) internal pure returns (bytes memory) {
        return vaa.payload;
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /// @dev Formats an 18-decimal amount as a human-readable "whole.dd" string.
    function _fmt(uint256 amount) internal pure returns (string memory) {
        uint256 whole = amount / 1e18;
        uint256 cents = (amount % 1e18) / 1e16; // 2 decimal places
        string memory centsStr = cents < 10
            ? string.concat("0", vm.toString(cents))
            : vm.toString(cents);
        return string.concat(vm.toString(whole), ".", centsStr);
    }
}
