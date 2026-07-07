// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2 as console} from "forge-std/console2.sol";
import {INttManager} from "mento-stabletoken-ntt/src/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "mento-stabletoken-ntt/src/interfaces/IWormholeTransceiver.sol";

import {NTTBridgeHarness} from "./NTTBridgeHarness.t.sol";
import {NTTTokenConfig} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTBridgeMatrix
/// @notice Machine-readable reporter behind the bridge-matrix dashboard
///         (script/bridge-matrix/). Sweeps EVERY configured token across every
///         ordered chain pair and records a per-lane status instead of
///         failing — a broken lane becomes a red cell, not an aborted run.
///
///         Statuses:
///           ok           lane bridged the full amount
///           fail         lane reverted (detail carries the decoded reason)
///           not_deployed src and/or dst has no NTT deployment yet
///           untestable   source is a locking hub — funding is out of scope
///                        (burn-mint only), so the lane cannot be driven
///
/// @dev Results are written to `out/bridge-matrix.json` (out/ is read-write in
///      foundry.toml). The test itself always passes; it is a reporter.
///
///      Run:  forge test --mc NTTBridgeMatrix -vv
contract NTTBridgeMatrixTest is NTTBridgeHarness {
    uint256 internal constant AMOUNT = 100e18;
    string internal constant OUTPUT_PATH = "out/bridge-matrix.json";

    function test_generateBridgeMatrix() public {
        string[5] memory tokens = ["USDm", "EURm", "GBPm", "JPYm", "CHFm"];

        string memory tokensJson = "";
        for (uint256 i = 0; i < tokens.length; i++) {
            _banner(string.concat(" Matrix: ", tokens[i]));
            if (i > 0) tokensJson = string.concat(tokensJson, ",");
            tokensJson = string.concat(tokensJson, _tokenMatrixJson(tokens[i]));
        }

        vm.writeFile(OUTPUT_PATH, string.concat("{\"tokens\":[", tokensJson, "]}"));
        console.log("bridge matrix written to %s", OUTPUT_PATH);
    }

    /// @dev Runs all ordered lanes for one token and returns its JSON object.
    function _tokenMatrixJson(string memory tokenName) internal returns (string memory) {
        NTTTokenConfig memory cfg = _loadTokenConfig(tokenName);

        ChainCtx[] memory ctxs = new ChainCtx[](cfg.chains.length);
        string memory chainsJson = "";
        for (uint256 i = 0; i < cfg.chains.length; i++) {
            ctxs[i] = _resolveChain(tokenName, cfg.chains[i]);
            if (i > 0) chainsJson = string.concat(chainsJson, ",");
            chainsJson = string.concat(chainsJson, "\"", ctxs[i].name, "\"");
        }

        string memory lanesJson = "";
        for (uint256 s = 0; s < ctxs.length; s++) {
            for (uint256 d = 0; d < ctxs.length; d++) {
                if (s == d) continue;
                (string memory status, string memory detail) = _laneStatus(ctxs[s], ctxs[d]);
                console.log("  %s -> %s : %s", ctxs[s].name, ctxs[d].name, status);

                if (bytes(lanesJson).length > 0) lanesJson = string.concat(lanesJson, ",");
                lanesJson = string.concat(
                    lanesJson,
                    "{\"src\":\"",
                    ctxs[s].name,
                    "\",\"dst\":\"",
                    ctxs[d].name,
                    "\",\"status\":\"",
                    status,
                    "\",\"detail\":\"",
                    detail,
                    "\"}"
                );
            }
        }

        return string.concat(
            "{\"token\":\"", tokenName, "\",\"chains\":[", chainsJson, "],\"lanes\":[", lanesJson, "]}"
        );
    }

    /// @dev Classifies one lane. Reverts inside the lane are caught via the
    ///      external self-call so the sweep continues.
    function _laneStatus(ChainCtx memory src, ChainCtx memory dst)
        internal
        returns (string memory status, string memory detail)
    {
        if (!src.deployed || !dst.deployed) {
            string memory missing = !src.deployed ? src.name : dst.name;
            if (!src.deployed && !dst.deployed) missing = string.concat(src.name, " and ", dst.name);
            return ("not_deployed", string.concat("NTT not deployed on ", missing));
        }
        if (!src.isBurning) {
            return ("untestable", "source is a locking hub; test funding is burn-mint only");
        }

        try this.runLaneExternal(src, dst) {
            return ("ok", "");
        } catch Error(string memory reason) {
            vm.clearMockedCalls();
            return ("fail", reason);
        } catch (bytes memory lowLevelData) {
            vm.clearMockedCalls();
            return ("fail", _describeRevert(lowLevelData));
        }
    }

    /// @dev External so _laneStatus can try/catch it. Not a test (name does not
    ///      start with `test`). Reverts bubble up to the catch blocks above.
    function runLaneExternal(ChainCtx memory src, ChainCtx memory dst) external {
        address sender = makeAddr(string.concat("matrix-sender-", src.name, "-", dst.name));
        address recipient = makeAddr(string.concat("matrix-recipient-", src.name, "-", dst.name));

        _fundBurnMint(src, sender, AMOUNT);
        uint256 delivered = _bridge(src, dst, AMOUNT, sender, recipient);
        require(delivered == AMOUNT, "delivered amount mismatch");
    }

    /// @dev Maps the well-known NTT misconfiguration errors to readable names;
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
        return string.concat("custom error ", vm.toString(abi.encodePacked(selector)));
    }
}
