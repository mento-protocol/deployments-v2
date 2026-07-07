// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2 as console} from "forge-std/console2.sol";
import {NTTBridgeHarness} from "./NTTBridgeHarness.t.sol";
import {NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTBridgeSweep
/// @notice Config-driven sweep: for each burn-mint token, bridge across EVERY
///         ordered pair of configured chains (all directions) and verify a
///         round-trip conserves supply. Reads topology straight from
///         `NTTConfig.sol` — the same source ConfigureNTT uses — so it
///         automatically covers new lanes (e.g. Polygon) once deployed.
///
/// @dev Chains present in the config but not yet deployed (no NttDeployHelper
///      on-chain) are skipped with a log. In normal operation every configured
///      chain is deployed; skipping only matters during the dev window.
///
///      Run:  forge test --mc NTTBridgeSweep -vv
contract NTTBridgeSweepTest is NTTBridgeHarness {
    function test_sweep_USDm_all_directions() public {
        _sweepToken("USDm");
    }

    function test_sweep_EURm_all_directions() public {
        _sweepToken("EURm");
    }

    /// @dev Bridges `amount` across every ordered (src != dst) deployed pair,
    ///      then asserts an A->B->A round-trip conserves the recipient's balance.
    function _sweepToken(string memory tokenName) internal {
        uint256 amount = 100e18;
        NTTTokenConfig memory cfg = _loadTokenConfig(tokenName);

        _banner(
            string.concat(
                " NTT bridge sweep: ", tokenName, " across ", vm.toString(cfg.chains.length), " configured chains"
            )
        );

        // Resolve every chain up front (forks are cached in the harness).
        ChainCtx[] memory ctxs = new ChainCtx[](cfg.chains.length);
        uint256 deployedCount;
        for (uint256 i = 0; i < cfg.chains.length; i++) {
            ctxs[i] = _resolveChain(tokenName, cfg.chains[i]);
            if (ctxs[i].deployed) {
                deployedCount++;
            } else {
                console.log("  [skip] %s: NTT not deployed on this chain yet", cfg.chains[i].chainName);
            }
        }
        console.log("");

        // Sweep every ordered pair.
        uint256 totalLanes = deployedCount * (deployedCount - 1);
        uint256 lanesRun;
        for (uint256 s = 0; s < ctxs.length; s++) {
            if (!ctxs[s].deployed) continue;
            for (uint256 d = 0; d < ctxs.length; d++) {
                if (s == d || !ctxs[d].deployed) continue;

                lanesRun++;
                console.log("lane %d/%d", lanesRun, totalLanes);

                address sender = makeAddr(string.concat(tokenName, "-sender-", ctxs[s].name));
                address recipient = makeAddr(string.concat(tokenName, "-recipient-", ctxs[d].name));

                // Fund the source freshly for this lane (burn-mint mint()).
                _fundBurnMint(ctxs[s], sender, amount);

                uint256 delivered = _bridge(ctxs[s], ctxs[d], amount, sender, recipient);
                assertEq(
                    delivered, amount, string.concat("lane delivered wrong amount: ", ctxs[s].name, "->", ctxs[d].name)
                );
            }
        }

        require(lanesRun > 0, "no deployed lanes to test");
        console.log("  swept %d directed lanes for %s", lanesRun, tokenName);

        // Round-trip conservation on the first two deployed chains: A->B->A.
        (uint256 a, uint256 b) = _firstTwoDeployed(ctxs);
        _assertRoundTrip(tokenName, ctxs[a], ctxs[b], amount);
    }

    /// @dev A->B->A must leave the round-tripper with exactly what they started
    ///      (minus nothing — burn-mint is 1:1). Proves both directions wire up.
    function _assertRoundTrip(string memory tokenName, ChainCtx memory a, ChainCtx memory b, uint256 amount) internal {
        console.log(string.concat("--- round-trip ", tokenName, ": ", a.name, " -> ", b.name, " -> ", a.name, " ---"));
        address user = makeAddr(string.concat(tokenName, "-roundtrip"));

        _fundBurnMint(a, user, amount);

        // A -> B
        uint256 gotOnB = _bridge(a, b, amount, user, user);
        assertEq(gotOnB, amount, "roundtrip: A->B lost funds");

        // B -> A (uses the real tokens just minted on B — no extra funding)
        vm.selectFork(a.forkId);
        uint256 backStart = a.token.balanceOf(user);
        uint256 gotBackOnA = _bridge(b, a, gotOnB, user, user);
        assertEq(gotBackOnA, amount, "roundtrip: B->A lost funds");

        vm.selectFork(a.forkId);
        assertEq(a.token.balanceOf(user) - backStart, amount, "roundtrip: final balance mismatch");
        console.log("  round-trip conserved %s %s", _fmt(amount), tokenName);
        console.log("");
    }

    function _firstTwoDeployed(ChainCtx[] memory ctxs) internal pure returns (uint256 a, uint256 b) {
        bool foundFirst;
        for (uint256 i = 0; i < ctxs.length; i++) {
            if (!ctxs[i].deployed) continue;
            if (!foundFirst) {
                (a, foundFirst) = (i, true);
            } else {
                return (a, i);
            }
        }
        revert("need >= 2 deployed chains for round-trip");
    }
}
