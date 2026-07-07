// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2 as console} from "forge-std/console2.sol";
import {INttManager} from "mento-stabletoken-ntt/src/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "mento-stabletoken-ntt/src/interfaces/IWormholeTransceiver.sol";

import {NTTBridgeHarness} from "./NTTBridgeHarness.t.sol";
import {NTTTokenConfig} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTBridgeOneWay
/// @notice Negative test for the partially-configured celo <> polygon window:
///         NTT deployed + ConfigureNTT run on Polygon (so Polygon knows Celo),
///         but ConfigureNTT NOT yet run on Celo (so Celo doesn't know Polygon).
///
///         In that state BOTH directions involving the unconfigured side must
///         fail, each at Celo's own gate:
///
///           celo -> polygon : reverts at the SOURCE — Celo's NttManager has no
///                             Polygon peer, so `_trimTransferAmount` reverts
///                             with `InvalidPeerDecimals()` before any VAA exists.
///           polygon -> celo : the send leg succeeds on Polygon, but delivery is
///                             rejected at the DESTINATION — Celo's transceiver
///                             has no Polygon wormhole peer, so `receiveMessage`
///                             reverts with `InvalidWormholePeer(...)`.
///
/// @dev State-aware: skips while Polygon is undeployed, and skips once Celo is
///      fully configured (at that point the positive sweep test covers the lanes).
///      Run it right after `DeployNTT`/`ConfigureNTT` on Polygon, before the
///      Celo ConfigureNTT Safe proposal executes.
///
///      Run:  TOKEN=USDm forge test --mc NTTBridgeOneWay -vv
contract NTTBridgeOneWayCeloPolygonTest is NTTBridgeHarness {
    uint256 internal constant AMOUNT = 100e18;

    function test_oneWay_celoPolygon_unconfiguredDirectionsRevert() public {
        string memory tokenName = vm.envOr("TOKEN", string("USDm"));
        NTTTokenConfig memory cfg = _loadTokenConfig(tokenName);

        ChainCtx memory celo = _resolveChain(tokenName, _chainByName(cfg, "celo"));
        ChainCtx memory polygon = _resolveChain(tokenName, _chainByName(cfg, "polygon"));

        // ── Live peer state ─────────────────────────────────────────────
        // The source gate only needs Celo, so it runs even before Polygon
        // is deployed. The dest gate additionally needs Polygon's contracts.
        vm.selectFork(celo.forkId);
        bool celoKnowsPolygon = celo.manager.getPeer(polygon.wormholeChainId).peerAddress != bytes32(0);
        bool polygonKnowsCelo = false;
        if (polygon.deployed) {
            vm.selectFork(polygon.forkId);
            polygonKnowsCelo = polygon.manager.getPeer(celo.wormholeChainId).peerAddress != bytes32(0);
        }

        _banner(string.concat(" One-way check: ", tokenName, "  celo <> polygon"));
        console.log("   polygon deployed:    %s", polygon.deployed);
        console.log("   celo knows polygon:  %s", celoKnowsPolygon);
        console.log("   polygon knows celo:  %s", polygonKnowsCelo);
        console.log("");

        if (celoKnowsPolygon) {
            console.log("[skip] celo already has a polygon peer - fully configured; use NTTBridgeSweep");
            vm.skip(true);
        }

        address sender = makeAddr("oneway-sender");
        address recipient = makeAddr("oneway-recipient");

        // ── 1. Source gate: celo -> polygon must revert on celo ─────────
        // Celo's manager has no Polygon peer, so the transfer dies in
        // _trimTransferAmount (peer decimals == 0) before publishing anything.
        _fundBurnMint(celo, sender, AMOUNT);
        vm.selectFork(celo.forkId);

        vm.startPrank(sender);
        celo.token.approve(address(celo.manager), AMOUNT);
        vm.expectRevert(INttManager.InvalidPeerDecimals.selector);
        celo.manager.transfer(AMOUNT, polygon.wormholeChainId, _toBytes32(recipient));
        vm.stopPrank();

        console.log("[ok] celo -> polygon: transfer reverted at SOURCE (no polygon peer on celo)");

        // ── 2. Dest gate: polygon -> celo must be rejected on celo ──────
        // The outbound leg on Polygon is real; delivery on Celo carries the
        // genuine Polygon transceiver as emitter, but Celo has never registered
        // it, so receiveMessage reverts with InvalidWormholePeer.
        if (!polygon.deployed) {
            console.log("[skip-half] %s NTT not deployed on polygon - dest gate needs DeployNTT first", tokenName);
            return;
        }
        if (!polygonKnowsCelo) {
            console.log("[skip-half] polygon has no celo peer - cannot form the send leg");
            console.log("            (run ConfigureNTT on polygon first to test the dest gate)");
            return;
        }

        _fundBurnMint(polygon, sender, AMOUNT);
        bytes memory whPayload = _sendLeg(polygon, celo, AMOUNT, sender, recipient);

        _mockVaaDelivery(polygon, celo, whPayload); // selects celo fork + mocks VAA verification
        uint256 recipientBefore = celo.token.balanceOf(recipient);

        vm.expectRevert(
            abi.encodeWithSelector(
                IWormholeTransceiver.InvalidWormholePeer.selector,
                polygon.wormholeChainId,
                _toBytes32(polygon.transceiver)
            )
        );
        IWormholeTransceiver(celo.transceiver).receiveMessage(whPayload);
        vm.clearMockedCalls();

        assertEq(celo.token.balanceOf(recipient), recipientBefore, "nothing must be minted on celo");
        console.log("[ok] polygon -> celo: delivery rejected at DESTINATION (InvalidWormholePeer on celo)");
    }
}
