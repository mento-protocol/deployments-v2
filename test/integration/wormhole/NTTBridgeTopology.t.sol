// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2 as console} from "forge-std/console2.sol";
import {INttManager} from "mento-stabletoken-ntt/src/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "mento-stabletoken-ntt/src/interfaces/IWormholeTransceiver.sol";

import {NTTBridgeHarness} from "./NTTBridgeHarness.t.sol";
import {NTTTokenConfig} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTBridgeTopology
/// @notice One test covering EVERY token across EVERY configured lane, ending
///         in a status matrix. Meant as a topology overview, not a debugger —
///         for a failing lane's full trace use NTTBridgeLane with SRC/DST/TOKEN.
///
///         Cells:
///           ok   lane bridged the full amount
///           X    lane reverted (reason listed under the matrix)
///           nc   NTT deployed on both ends but peers not registered yet
///                (listed under the matrix with which chain needs ConfigureNTT)
///           nd   NTT not deployed on src and/or dst yet
///           -    chain pair not part of this token's configured topology
///
/// @dev Lanes are preflighted with view calls (manager + transceiver peers on
///      both ends), so a partially-rolled-out lane shows up as `nc` without
///      ever reverting. Only lanes that *claim* to be configured are bridged;
///      an unexpected revert there becomes an X via an external self-call
///      try/catch (with cheatcode state reset, since pranks survive reverts).
///      The test fails at the end if any lane is X; `nc`/`nd`/`-` are neutral.
///
///      Run:  forge test --mc NTTBridgeTopology -vv
contract NTTBridgeTopologyTest is NTTBridgeHarness {
    uint256 internal constant AMOUNT = 100e18;

    /// @dev Lane notes accumulated in MEMORY on purpose: reverted lane calls
    ///      hop forks, and storage writes interleaved with those reverts can be
    ///      unwound by the fork journal — memory is immune to that.
    struct Report {
        string[] failures; // "token src->dst: reason"
        uint256 failCount;
        string[] unconfigured; // "token src->dst: needs ConfigureNTT on ..."
        uint256 ncCount;
    }

    function test_topology_all_tokens_all_lanes() public {
        string[5] memory tokens = ["USDm", "EURm", "GBPm", "JPYm", "CHFm"];

        // Union of chains across all token configs (config-driven, no hardcoding).
        string[] memory allChains = _chainUnion(tokens);

        // Directed lane list over the union: (src, dst) for every s != d pair.
        uint256 laneCount = allChains.length * (allChains.length - 1);
        string[] memory laneHeaders = new string[](laneCount);
        {
            uint256 l;
            for (uint256 s = 0; s < allChains.length; s++) {
                for (uint256 d = 0; d < allChains.length; d++) {
                    if (s == d) continue;
                    laneHeaders[l++] = string.concat(allChains[s], ">", allChains[d]);
                }
            }
        }

        Report memory report;
        report.failures = new string[](tokens.length * laneCount);
        report.unconfigured = new string[](tokens.length * laneCount);

        // Run every token over every lane.
        string[][] memory cells = new string[][](tokens.length);
        for (uint256 t = 0; t < tokens.length; t++) {
            cells[t] = _runToken(tokens[t], allChains, report);
        }

        // ── Print the matrix ────────────────────────────────────────────
        console.log("");
        _banner(" NTT bridge topology");

        string memory header = _pad("token", 8);
        for (uint256 l = 0; l < laneCount; l++) {
            header = string.concat(header, _pad(laneHeaders[l], _colWidth(laneHeaders[l])));
        }
        console.log(header);

        for (uint256 t = 0; t < tokens.length; t++) {
            string memory row = _pad(tokens[t], 8);
            for (uint256 l = 0; l < laneCount; l++) {
                row = string.concat(row, _pad(cells[t][l], _colWidth(laneHeaders[l])));
            }
            console.log(row);
        }

        console.log("");
        console.log(
            "legend: ok = bridged | X = failed | nc = not configured | nd = not deployed | - = not in token config"
        );

        if (report.ncCount > 0) {
            console.log("");
            console.log("not configured:");
            for (uint256 i = 0; i < report.ncCount; i++) {
                console.log("  %s", report.unconfigured[i]);
            }
        }

        if (report.failCount > 0) {
            console.log("");
            console.log("failures:");
            for (uint256 i = 0; i < report.failCount; i++) {
                console.log("  %s", report.failures[i]);
            }
        }
        console.log("");

        require(report.failCount == 0, "topology has failing lanes (see matrix above)");
    }

    /// @dev Runs all union lanes for one token; returns one matrix cell per lane.
    function _runToken(string memory tokenName, string[] memory allChains, Report memory report)
        internal
        returns (string[] memory cells)
    {
        NTTTokenConfig memory cfg = _loadTokenConfig(tokenName);

        // Resolve the token's configured chains; map union index -> ctx (or absent).
        ChainCtx[] memory byUnion = new ChainCtx[](allChains.length);
        bool[] memory inConfig = new bool[](allChains.length);
        for (uint256 i = 0; i < cfg.chains.length; i++) {
            for (uint256 u = 0; u < allChains.length; u++) {
                if (keccak256(bytes(cfg.chains[i].chainName)) == keccak256(bytes(allChains[u]))) {
                    byUnion[u] = _resolveChain(tokenName, cfg.chains[i]);
                    inConfig[u] = true;
                }
            }
        }

        cells = new string[](allChains.length * (allChains.length - 1));
        uint256 l;
        for (uint256 s = 0; s < allChains.length; s++) {
            for (uint256 d = 0; d < allChains.length; d++) {
                if (s == d) continue;
                cells[l++] = _laneCell(tokenName, byUnion, inConfig, s, d, report);
            }
        }
    }

    function _laneCell(
        string memory tokenName,
        ChainCtx[] memory byUnion,
        bool[] memory inConfig,
        uint256 s,
        uint256 d,
        Report memory report
    ) internal returns (string memory) {
        if (!inConfig[s] || !inConfig[d]) return "-";
        if (!byUnion[s].deployed || !byUnion[d].deployed) return "nd";

        string memory missing = _preflightLane(byUnion[s], byUnion[d]);
        if (bytes(missing).length > 0) {
            report.unconfigured[report.ncCount++] = _laneNote(tokenName, byUnion[s].name, byUnion[d].name, missing);
            return "nc";
        }

        try this.runLaneExternal(byUnion[s], byUnion[d]) {
            return "ok";
        } catch Error(string memory reason) {
            _resetCheatcodes();
            report.failures[report.failCount++] = _laneNote(tokenName, byUnion[s].name, byUnion[d].name, reason);
            return "X";
        } catch (bytes memory lowLevelData) {
            _resetCheatcodes();
            report.failures[report.failCount++] =
                _laneNote(tokenName, byUnion[s].name, byUnion[d].name, _describeRevert(lowLevelData));
            return "X";
        }
    }

    /// @dev Checks the four peer registrations a lane needs (manager peer +
    ///      transceiver wormhole peer, on each end) via view calls. Returns ""
    ///      when fully wired, else which chain(s) still need ConfigureNTT.
    function _preflightLane(ChainCtx memory src, ChainCtx memory dst) internal returns (string memory) {
        vm.selectFork(src.forkId);
        bool srcOk = src.manager.getPeer(dst.wormholeChainId).peerAddress != bytes32(0)
            && IWormholeTransceiver(src.transceiver).getWormholePeer(dst.wormholeChainId) != bytes32(0);

        vm.selectFork(dst.forkId);
        bool dstOk = dst.manager.getPeer(src.wormholeChainId).peerAddress != bytes32(0)
            && IWormholeTransceiver(dst.transceiver).getWormholePeer(src.wormholeChainId) != bytes32(0);

        if (srcOk && dstOk) return "";
        if (!srcOk && !dstOk) return string.concat("needs ConfigureNTT on ", src.name, " and ", dst.name);
        return string.concat("needs ConfigureNTT on ", srcOk ? dst.name : src.name);
    }

    /// @dev External so lane reverts can be caught. Not a test function.
    function runLaneExternal(ChainCtx memory src, ChainCtx memory dst) external {
        address sender = makeAddr(string.concat("topo-sender-", src.name, "-", dst.name));
        address recipient = makeAddr(string.concat("topo-recipient-", src.name, "-", dst.name));

        _fund(src, sender, AMOUNT);
        uint256 delivered = _bridge(src, dst, AMOUNT, sender, recipient);
        require(delivered == AMOUNT, "delivered amount mismatch");
    }

    function _laneNote(string memory tokenName, string memory src, string memory dst, string memory note)
        internal
        pure
        returns (string memory)
    {
        return string.concat(tokenName, " ", src, "->", dst, ": ", note);
    }

    /// @dev Maps well-known NTT misconfiguration errors to readable names;
    ///      anything else surfaces as its raw 4-byte selector.
    function _describeRevert(bytes memory data) internal view returns (string memory) {
        if (data.length < 4) return "revert (no data)";
        bytes4 selector = bytes4(data);
        if (selector == INttManager.InvalidPeerDecimals.selector) {
            return "InvalidPeerDecimals: peer not configured on source manager";
        }
        if (selector == IWormholeTransceiver.InvalidWormholePeer.selector) {
            return "InvalidWormholePeer: emitter not registered on destination transceiver";
        }
        if (selector == bytes4(keccak256("CheatcodeError(string)"))) {
            return string.concat("cheatcode error: ", _decodeStringPayload(data));
        }
        return string.concat("custom error ", vm.toString(abi.encodePacked(selector)));
    }

    /// @dev Decodes the string argument of a `SomeError(string)` revert payload.
    function _decodeStringPayload(bytes memory data) internal pure returns (string memory) {
        bytes memory tail = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; i++) {
            tail[i - 4] = data[i];
        }
        return abi.decode(tail, (string));
    }

    // ── Matrix formatting ───────────────────────────────────────────────

    /// @dev Ordered union of chain names across all token configs.
    function _chainUnion(string[5] memory tokens) internal pure returns (string[] memory) {
        string[] memory buf = new string[](8);
        uint256 n;
        for (uint256 t = 0; t < tokens.length; t++) {
            NTTTokenConfig memory cfg = _loadTokenConfig(tokens[t]);
            for (uint256 i = 0; i < cfg.chains.length; i++) {
                bool seen;
                for (uint256 u = 0; u < n; u++) {
                    if (keccak256(bytes(buf[u])) == keccak256(bytes(cfg.chains[i].chainName))) {
                        seen = true;
                        break;
                    }
                }
                if (!seen) buf[n++] = cfg.chains[i].chainName;
            }
        }
        string[] memory out = new string[](n);
        for (uint256 u = 0; u < n; u++) {
            out[u] = buf[u];
        }
        return out;
    }

    function _colWidth(string memory headerText) internal pure returns (uint256) {
        return bytes(headerText).length + 3;
    }

    function _pad(string memory s, uint256 width) internal pure returns (string memory) {
        while (bytes(s).length < width) {
            s = string.concat(s, " ");
        }
        return s;
    }
}
