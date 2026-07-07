// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

import {INttManager} from "mento-stabletoken-ntt/src/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "mento-stabletoken-ntt/src/interfaces/IWormholeTransceiver.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {INttToken} from "mento-stabletoken-ntt/src/interfaces/INttToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {NTTConfig, NTTTokenConfig, NTTChainConfig} from "script/config/wormhole/NTTConfig.sol";

interface INttDeployHelper {
    function nttManagerProxy() external view returns (address);
    function transceiverProxy() external view returns (address);
}

/// @dev WormholeTransceiver exposes the core bridge it was deployed against as
///      a public immutable `wormhole` — not on IWormholeTransceiver, so declared here.
interface IWormholeTransceiverCore {
    function wormhole() external view returns (address);
}

/// @title NTTBridgeHarness
/// @notice Reusable base for NTT cross-chain bridge fork tests. Forks any two
///         configured chains and simulates a full Wormhole NTT transfer between
///         them against the *live, deployed* contracts — proving ConfigureNTT
///         wired up peers, threshold, and mint permissions correctly.
///
/// @dev The only crypto gate (`wormhole.parseAndVerifyVM`) is mocked on the
///      destination; everything else the receive path checks (peer addresses,
///      threshold, minter role) is genuine on-chain state, so a missed or
///      incorrect ConfigureNTT surfaces as a revert.
///
///      Topology (chains, wormhole IDs, token labels, burn/lock modes) is read
///      from `script/config/wormhole/NTTConfig.sol` — the same source of truth
///      ConfigureNTT uses. No lane data is duplicated here.
abstract contract NTTBridgeHarness is Test {
    // Treb registry file + namespace used to resolve the per-token NttDeployHelper.
    string internal constant REGISTRY_PATH = ".treb/registry.json";
    string internal constant NAMESPACE = "mainnet";

    // Encoded transceiver instructions with count=0 (single 0x00 byte).
    // Empty `bytes` reverts in parseTransceiverInstructions; count-prefix required.
    bytes internal constant EMPTY_INSTRUCTIONS = hex"00";

    // Default consistency level used by WormholeTransceiver (202 = finalized).
    uint8 internal constant CONSISTENCY_LEVEL = 202;

    // ── Resolved per-chain context (fork id + live contracts) ───────────
    struct ChainCtx {
        string name; // "celo", "monad", ...
        uint256 evmChainId;
        uint16 wormholeChainId;
        address coreBridge;
        uint256 forkId;
        INttManager manager;
        address transceiver;
        IERC20 token;
        bool deployed; // NttDeployHelper present on this fork?
        bool isBurning; // live manager mode: BURNING (true) or LOCKING (false)
    }

    // Cache forks by evmChainId so each chain is forked at most once per run.
    mapping(uint256 => uint256) internal _forkIdByChain;
    mapping(uint256 => bool) internal _forkCreated;

    // Monotonic nonce so every simulated VAA gets a unique hash (replay guard).
    uint256 internal _vaaNonce;

    // ── RPC resolution (env first, public fallback) ─────────────────────

    function _rpcUrl(string memory chainName) internal view returns (string memory) {
        // e.g. celo -> CELO_RPC_URL
        string memory envVar = string.concat(_upper(chainName), "_RPC_URL");
        string memory fallbackUrl = _publicRpc(chainName);
        return vm.envOr(envVar, fallbackUrl);
    }

    function _publicRpc(string memory chainName) internal pure returns (string memory) {
        bytes32 h = keccak256(bytes(chainName));
        if (h == keccak256("celo")) return "https://forno.celo.org";
        if (h == keccak256("monad")) return "https://rpc.monad.xyz";
        if (h == keccak256("polygon")) return "https://polygon-rpc.com";
        if (h == keccak256("base")) return "https://mainnet.base.org";
        revert(string.concat("no public RPC fallback for chain: ", chainName));
    }

    // ── Config access ───────────────────────────────────────────────────

    function _loadTokenConfig(string memory tokenName) internal pure returns (NTTTokenConfig memory) {
        bytes32 h = keccak256(bytes(tokenName));
        if (h == keccak256("USDm")) return NTTConfig.getUSDmConfig();
        if (h == keccak256("EURm")) return NTTConfig.getEURmConfig();
        if (h == keccak256("GBPm")) return NTTConfig.getGBPmConfig();
        if (h == keccak256("JPYm")) return NTTConfig.getJPYmConfig();
        if (h == keccak256("CHFm")) return NTTConfig.getCHFmConfig();
        revert(string.concat("Unknown token: ", tokenName));
    }

    /// @dev Resolves a chain's fork + live NTT contracts for a given token.
    ///      Forks lazily (cached). The NttDeployHelper is per-token (same address
    ///      across chains, but different per token) and is read from the treb
    ///      registry. If it isn't present in the registry OR has no code on the
    ///      fork, marks the context `deployed = false` so callers can skip —
    ///      this only happens in the dev window before a chain is deployed.
    function _resolveChain(string memory tokenName, NTTChainConfig memory chainCfg)
        internal
        returns (ChainCtx memory ctx)
    {
        ctx.name = chainCfg.chainName;
        ctx.evmChainId = chainCfg.evmChainId;
        ctx.wormholeChainId = chainCfg.wormholeChainId;

        if (!_forkCreated[chainCfg.evmChainId]) {
            _forkIdByChain[chainCfg.evmChainId] = vm.createFork(_rpcUrl(chainCfg.chainName));
            _forkCreated[chainCfg.evmChainId] = true;
        }
        ctx.forkId = _forkIdByChain[chainCfg.evmChainId];

        address helper = _registryHelper(tokenName, chainCfg.evmChainId);
        if (helper == address(0)) {
            ctx.deployed = false;
            return ctx;
        }

        vm.selectFork(ctx.forkId);
        if (helper.code.length == 0) {
            ctx.deployed = false;
            return ctx;
        }
        ctx.deployed = true;
        ctx.manager = INttManager(INttDeployHelper(helper).nttManagerProxy());
        ctx.transceiver = INttDeployHelper(helper).transceiverProxy();
        ctx.token = IERC20(ctx.manager.token());
        // Mode enum: LOCKING = 0, BURNING = 1.
        ctx.isBurning = ctx.manager.getMode() == 1;
        // Read the core bridge straight off the deployed transceiver, so no
        // per-chain addressbook lookup is needed here.
        ctx.coreBridge = IWormholeTransceiverCore(ctx.transceiver).wormhole();
    }

    /// @dev Reads `NttDeployHelper:<token>` for a chain from the treb registry
    ///      JSON at path `.<chainId>.<namespace>["NttDeployHelper:<token>"]`.
    ///      Returns address(0) if not present (chain not deployed for this token).
    function _registryHelper(string memory tokenName, uint256 evmChainId) internal view returns (address) {
        string memory json = vm.readFile(REGISTRY_PATH);
        string memory key =
            string.concat(".", vm.toString(evmChainId), ".", NAMESPACE, "[\"NttDeployHelper:", tokenName, "\"]");
        if (!vm.keyExistsJson(json, key)) return address(0);
        return vm.parseJsonAddress(json, key);
    }

    // ── Core bridge primitive ───────────────────────────────────────────

    /// @notice Simulates a full NTT transfer of `amount` from `src` to `dst`,
    ///         crediting `recipient` on the destination. Returns the amount
    ///         delivered (== amount for a healthy config). Funding of the source
    ///         is the caller's responsibility (see _fundBurnMint).
    ///
    /// @dev Assumes burn-mint semantics on both ends (USDm/EURm). Emits a
    ///      readable log trace of balances/supply before and after.
    function _bridge(ChainCtx memory src, ChainCtx memory dst, uint256 amount, address sender, address recipient)
        internal
        returns (uint256 delivered)
    {
        bytes memory whPayload = _sendLeg(src, dst, amount, sender, recipient);

        // ── DESTINATION: deliver via faked (but correctly-addressed) VAA ─
        _mockVaaDelivery(src, dst, whPayload);
        uint256 dstSupplyBefore = dst.token.totalSupply();
        uint256 recipientBefore = dst.token.balanceOf(recipient);
        console.log("  %s total supply before   = %s", _tag(dst.name), _fmt(dstSupplyBefore));

        IWormholeTransceiver(dst.transceiver).receiveMessage(whPayload);
        vm.clearMockedCalls();

        console.log("  %s total supply after    = %s", _tag(dst.name), _fmt(dst.token.totalSupply()));
        delivered = dst.token.balanceOf(recipient) - recipientBefore;
        if (dst.isBurning) {
            console.log("  %s recipient minted      = %s", _tag(dst.name), _fmt(delivered));
        } else {
            console.log("  %s recipient unlocked    = %s", _tag(dst.name), _fmt(delivered));
        }
        console.log("");
    }

    /// @dev Source half of `_bridge`: performs the real outbound transfer on
    ///      `src` and returns the Wormhole payload published by the core bridge.
    function _sendLeg(ChainCtx memory src, ChainCtx memory dst, uint256 amount, address sender, address recipient)
        internal
        returns (bytes memory whPayload)
    {
        vm.selectFork(src.forkId);
        console.log("--- %s -> %s : bridging %s ------------", src.name, dst.name, _fmt(amount));

        uint256 srcSupplyBefore = src.token.totalSupply();
        uint256 srcLockedBefore = src.token.balanceOf(address(src.manager));
        console.log("  %s sender balance before = %s", _tag(src.name), _fmt(src.token.balanceOf(sender)));
        console.log("  %s total supply before   = %s", _tag(src.name), _fmt(srcSupplyBefore));

        (, uint256 fee) = src.manager.quoteDeliveryPrice(dst.wormholeChainId, EMPTY_INSTRUCTIONS);
        vm.deal(sender, fee);

        vm.startPrank(sender);
        src.token.approve(address(src.manager), amount);
        vm.recordLogs();
        src.manager.transfer{value: fee}(amount, dst.wormholeChainId, _toBytes32(recipient));
        vm.stopPrank();

        console.log("  %s total supply after    = %s", _tag(src.name), _fmt(src.token.totalSupply()));
        if (src.isBurning) {
            console.log(
                "  %s burned                = %s", _tag(src.name), _fmt(srcSupplyBefore - src.token.totalSupply())
            );
        } else {
            console.log(
                "  %s locked in manager     = %s",
                _tag(src.name),
                _fmt(src.token.balanceOf(address(src.manager)) - srcLockedBefore)
            );
        }

        whPayload = _captureWormholePayload(src.coreBridge);
        require(whPayload.length > 0, "no wormhole message published on source");
    }

    /// @dev Destination half of `_bridge`, minus the actual `receiveMessage`
    ///      call: selects the `dst` fork and mocks `parseAndVerifyVM` to return
    ///      a VAA correctly addressed from `src`'s transceiver. The caller then
    ///      invokes `receiveMessage` itself — optionally under `expectRevert`
    ///      for negative (misconfiguration) tests — and should call
    ///      `vm.clearMockedCalls()` afterwards.
    function _mockVaaDelivery(ChainCtx memory src, ChainCtx memory dst, bytes memory whPayload) internal {
        vm.selectFork(dst.forkId);

        _vaaNonce++;
        IWormhole.VM memory vaa = _buildVM({
            emitterChainId: src.wormholeChainId,
            emitterAddress: _toBytes32(src.transceiver),
            payload: whPayload,
            uniqueHash: keccak256(abi.encode(src.name, dst.name, _vaaNonce, whPayload))
        });

        vm.mockCall(
            dst.coreBridge, abi.encodeWithSelector(IWormhole.parseAndVerifyVM.selector), abi.encode(vaa, true, "")
        );
    }

    // ── Funding (burn-mint only) ────────────────────────────────────────

    /// @dev Funds `to` with `amount` of a burn-mint token by pranking the
    ///      NttManager's minter role. Only valid where the token is burn-mint.
    function _fundBurnMint(ChainCtx memory chain, address to, uint256 amount) internal {
        vm.selectFork(chain.forkId);
        vm.prank(address(chain.manager));
        INttToken(address(chain.token)).mint(to, amount);
        require(chain.token.balanceOf(to) >= amount, "funding failed (not burn-mint?)");
    }

    // ── Log capture / VAA construction ──────────────────────────────────

    function _captureWormholePayload(address coreBridge) internal returns (bytes memory) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("LogMessagePublished(address,uint64,uint32,bytes,uint8)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == coreBridge && logs[i].topics[0] == topic) {
                (,, bytes memory payload,) = abi.decode(logs[i].data, (uint64, uint32, bytes, uint8));
                return payload;
            }
        }
        return "";
    }

    function _buildVM(uint16 emitterChainId, bytes32 emitterAddress, bytes memory payload, bytes32 uniqueHash)
        internal
        pure
        returns (IWormhole.VM memory vaa)
    {
        vaa.version = 1;
        vaa.emitterChainId = emitterChainId;
        vaa.emitterAddress = emitterAddress;
        vaa.consistencyLevel = CONSISTENCY_LEVEL;
        vaa.payload = payload;
        vaa.signatures = new IWormhole.Signature[](0);
        vaa.hash = uniqueHash;
    }

    // ── Small utils ─────────────────────────────────────────────────────

    /// @dev Chain label padded to a fixed width so amounts align across chains.
    function _tag(string memory chainName) internal pure returns (string memory tag) {
        tag = string.concat("[", chainName, "]");
        while (bytes(tag).length < 9) {
            // 9 = len("[polygon]"), the widest configured chain
            tag = string.concat(tag, " ");
        }
    }

    function _banner(string memory title) internal view {
        console.log("========================================================");
        console.log(title);
        console.log("========================================================");
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

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /// @dev Formats an 18-decimal amount as "whole.dd".
    function _fmt(uint256 amount) internal pure returns (string memory) {
        uint256 whole = amount / 1e18;
        uint256 cents = (amount % 1e18) / 1e16;
        string memory centsStr = cents < 10 ? string.concat("0", vm.toString(cents)) : vm.toString(cents);
        return string.concat(vm.toString(whole), ".", centsStr);
    }

    function _upper(string memory s) internal pure returns (string memory) {
        bytes memory src = bytes(s);
        bytes memory out = new bytes(src.length); // fresh buffer — do NOT alias `s`
        for (uint256 i = 0; i < src.length; i++) {
            out[i] = (src[i] >= 0x61 && src[i] <= 0x7A) ? bytes1(uint8(src[i]) - 32) : src[i];
        }
        return string(out);
    }
}
