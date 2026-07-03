// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2 as console} from "forge-std/console2.sol";
import {NTTBridgeHarness} from "./NTTBridgeHarness.t.sol";
import {NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTBridgeLane
/// @notice Single-lane bridge test parameterized by env vars, for iterating on
///         one specific direction (e.g. a newly-deployed Polygon lane).
///
/// @dev Reads SRC, DST, TOKEN from the environment and resolves both chains from
///      NTTConfig. Defaults to celo -> monad USDm if unset.
///
///      Run:  SRC=celo DST=monad TOKEN=USDm forge test --mc NTTBridgeLane -vv
contract NTTBridgeLaneTest is NTTBridgeHarness {
    function test_bridge_single_direction() public {
        string memory srcName = vm.envOr("SRC", string("celo"));
        string memory dstName = vm.envOr("DST", string("monad"));
        string memory tokenName = vm.envOr("TOKEN", string("USDm"));
        uint256 amount = vm.envOr("AMOUNT", uint256(100e18));

        NTTTokenConfig memory cfg = _loadTokenConfig(tokenName);
        ChainCtx memory src = _resolveChain(tokenName, _chainByName(cfg, srcName));
        ChainCtx memory dst = _resolveChain(tokenName, _chainByName(cfg, dstName));

        require(src.deployed, string.concat("NTT not deployed on source: ", srcName));
        require(dst.deployed, string.concat("NTT not deployed on destination: ", dstName));

        console.log("========================================================");
        console.log(" NTT lane: %s  %s -> %s", tokenName, srcName, dstName);
        console.log("========================================================");

        address sender = makeAddr("lane-sender");
        address recipient = makeAddr("lane-recipient");

        _fundBurnMint(src, sender, amount);
        uint256 delivered = _bridge(src, dst, amount, sender, recipient);

        assertEq(delivered, amount, "lane delivered wrong amount");
        console.log("  lane OK: delivered %s %s to recipient", _fmt(delivered), tokenName);
    }

    function _chainByName(NTTTokenConfig memory cfg, string memory chainName)
        internal
        pure
        returns (NTTChainConfig memory)
    {
        for (uint256 i = 0; i < cfg.chains.length; i++) {
            if (keccak256(bytes(cfg.chains[i].chainName)) == keccak256(bytes(chainName))) {
                return cfg.chains[i];
            }
        }
        revert(string.concat("chain not in token config: ", chainName));
    }
}
