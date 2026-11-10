// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IStableTokenV2} from "lib/mento-core/contracts/interfaces/IStableTokenV2.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev The subset of the MentoGovernor (OpenZeppelin Governor) ABI the checker needs.
interface IGovernorPayload {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    function state(uint256 proposalId) external view returns (uint8);

    function timelock() external view returns (address);
}

/// @dev Minimal interface for the Broker's auto-generated public mapping getters.
interface IBrokerTradingLimits {
    function tradingLimitsConfig(bytes32 limitId)
        external
        view
        returns (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags);

    function tradingLimitsState(bytes32 limitId)
        external
        view
        returns (uint32 lastUpdated0, uint32 lastUpdated1, int48 netflow0, int48 netflow1, int48 netflowGlobal);
}

/**
 * @title MGP20Payload
 * @notice Pure decoding and shape validation of the MGP-20 `propose` calldata.
 * @dev Deliberately free of chain reads so it can be unit-tested against synthetic payloads
 *      (test/unit/MGP20Payload.t.sol). The shape it enforces is the one `MGP20.sol` produces:
 *      40 `Broker.configureTradingLimit` calls, four per exchange in the order reset-FX, set-FX,
 *      reset-USDm, set-USDm, every reset config empty, every set config LG-only with a positive
 *      limit, every exchange of the expected set used exactly once.
 */
library MGP20Payload {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint8 internal constant LG = 4;
    uint256 internal constant POOL_COUNT = 10;
    uint256 internal constant CALLS_PER_POOL = 4;
    uint256 internal constant CALL_COUNT = POOL_COUNT * CALLS_PER_POOL;

    /// @dev configureTradingLimit(bytes32,address,(uint32,uint32,int48,int48,int48,uint8)):
    ///      4 selector bytes + 2 head words + 6 static tuple words.
    uint256 internal constant CONFIGURE_CALLDATA_LENGTH = 4 + 32 * 8;

    bytes4 internal constant PROPOSE_SELECTOR = IGovernorPayload.propose.selector;
    bytes4 internal constant CONFIGURE_SELECTOR = IBroker.configureTradingLimit.selector;

    /// @param exchangeId Live exchange id on the BiPoolManager.
    /// @param fxToken The FX stable of the pair.
    /// @param usdmToken The USDm leg of the pair.
    struct ExpectedPool {
        bytes32 exchangeId;
        address fxToken;
        address usdmToken;
    }

    /// @dev The limits frozen in the payload for one exchange, in payload order.
    struct FrozenLimits {
        bytes32 exchangeId;
        address fxToken;
        address usdmToken;
        int48 fxLimit;
        int48 usdmLimit;
    }

    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    /// @notice Validates the outer selector and ABI-decodes the `propose` arguments.
    function decodePropose(bytes memory input) internal pure returns (Proposal memory proposal) {
        require(input.length >= 4, "MGP20Payload: input shorter than a selector");
        require(
            bytes4(input) == PROPOSE_SELECTOR, "MGP20Payload: not a propose(address[],uint256[],bytes[],string) call"
        );
        (proposal.targets, proposal.values, proposal.calldatas, proposal.description) =
            abi.decode(stripSelector(input), (address[], uint256[], bytes[], string));
    }

    /// @notice Asserts the MGP-20 shape of a decoded proposal against the expected exchange set
    ///         and returns the frozen limits per exchange, in payload order.
    /// @dev Pools may appear in any order in the payload (MGP20.sol orders them by its own
    ///      config list, the BiPoolManager by creation); each expected exchange must be used
    ///      exactly once and each call's token must match that exchange's live assets.
    function validate(Proposal memory proposal, address broker, ExpectedPool[] memory pools)
        internal
        pure
        returns (FrozenLimits[] memory frozen)
    {
        require(pools.length == POOL_COUNT, "MGP20Payload: expected exactly 10 exchanges");
        require(proposal.targets.length == CALL_COUNT, "MGP20Payload: expected exactly 40 targets");
        require(proposal.values.length == CALL_COUNT, "MGP20Payload: expected exactly 40 values");
        require(proposal.calldatas.length == CALL_COUNT, "MGP20Payload: expected exactly 40 calldatas");

        frozen = new FrozenLimits[](POOL_COUNT);
        bool[] memory used = new bool[](POOL_COUNT);

        for (uint256 g = 0; g < POOL_COUNT; g++) {
            uint256 base = g * CALLS_PER_POOL;
            (bytes32 exchangeId,,) = decodeConfigureCall(proposal, base);

            uint256 p = indexOf(pools, exchangeId);
            require(p < POOL_COUNT, string.concat("MGP20Payload: unknown exchange id in group ", vm.toString(g)));
            require(!used[p], string.concat("MGP20Payload: exchange used twice, group ", vm.toString(g)));
            used[p] = true;

            ExpectedPool memory pool = pools[p];
            expectCall(proposal, base, broker, exchangeId, pool.fxToken, false);
            int48 fxLimit = expectCall(proposal, base + 1, broker, exchangeId, pool.fxToken, true);
            expectCall(proposal, base + 2, broker, exchangeId, pool.usdmToken, false);
            int48 usdmLimit = expectCall(proposal, base + 3, broker, exchangeId, pool.usdmToken, true);

            frozen[g] = FrozenLimits({
                exchangeId: exchangeId,
                fxToken: pool.fxToken,
                usdmToken: pool.usdmToken,
                fxLimit: fxLimit,
                usdmLimit: usdmLimit
            });
        }

        for (uint256 p = 0; p < POOL_COUNT; p++) {
            require(
                used[p], string.concat("MGP20Payload: expected exchange missing from payload, index ", vm.toString(p))
            );
        }
    }

    /// @dev Checks one call of the payload: Broker target, zero value, configureTradingLimit
    ///      selector with exactly its ABI length, the expected exchange id and token, and either
    ///      an empty reset config or an LG-only set config with a positive limit.
    function expectCall(
        Proposal memory proposal,
        uint256 index,
        address broker,
        bytes32 exchangeId,
        address token,
        bool isSet
    ) internal pure returns (int48 limitGlobal) {
        string memory at = string.concat("MGP20Payload: call #", vm.toString(index));
        require(proposal.targets[index] == broker, string.concat(at, " target is not the Broker"));
        require(proposal.values[index] == 0, string.concat(at, " value is not zero"));

        (bytes32 id, address tok, ITradingLimits.Config memory cfg) = decodeConfigureCall(proposal, index);
        require(id == exchangeId, string.concat(at, " exchange id does not match its group"));
        require(tok == token, string.concat(at, isSet ? " set token mismatch" : " reset token mismatch"));

        if (!isSet) {
            require(
                cfg.flags == 0 && cfg.limitGlobal == 0 && cfg.limit0 == 0 && cfg.limit1 == 0 && cfg.timestep0 == 0
                    && cfg.timestep1 == 0,
                string.concat(at, " reset config is not empty")
            );
            return 0;
        }

        require(cfg.flags == LG, string.concat(at, " set config flags are not LG-only"));
        require(cfg.limitGlobal > 0, string.concat(at, " set config limitGlobal is not positive"));
        require(
            cfg.limit0 == 0 && cfg.limit1 == 0 && cfg.timestep0 == 0 && cfg.timestep1 == 0,
            string.concat(at, " set config carries L0/L1 fields")
        );
        return cfg.limitGlobal;
    }

    /// @dev Decodes one configureTradingLimit call, rejecting any other selector or length.
    function decodeConfigureCall(Proposal memory proposal, uint256 index)
        internal
        pure
        returns (bytes32 exchangeId, address token, ITradingLimits.Config memory cfg)
    {
        bytes memory data = proposal.calldatas[index];
        string memory at = string.concat("MGP20Payload: call #", vm.toString(index));
        require(data.length == CONFIGURE_CALLDATA_LENGTH, string.concat(at, " has an unexpected calldata length"));
        require(bytes4(data) == CONFIGURE_SELECTOR, string.concat(at, " is not configureTradingLimit"));
        (exchangeId, token, cfg) = abi.decode(stripSelector(data), (bytes32, address, ITradingLimits.Config));
    }

    function indexOf(ExpectedPool[] memory pools, bytes32 exchangeId) internal pure returns (uint256) {
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].exchangeId == exchangeId) return i;
        }
        return type(uint256).max;
    }

    /// @dev Returns `data` without its first four bytes.
    function stripSelector(bytes memory data) internal pure returns (bytes memory out) {
        require(data.length >= 4, "MGP20Payload: data shorter than a selector");
        out = new bytes(data.length - 4);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[i + 4];
        }
    }

    /// @notice Parses the contents of a raw calldata file: surrounding whitespace (including a
    ///         trailing newline) is ignored and the remaining 0x-prefixed hex is decoded.
    function parseCalldataFile(string memory contents) internal pure returns (bytes memory) {
        string memory hexString = trim(contents);
        require(bytes(hexString).length > 0, "MGP20Payload: calldata file is empty");
        return vm.parseBytes(hexString);
    }

    /// @notice Parses a decimal or 0x-prefixed hex number (broadcast receipts store blockNumber as hex).
    function parseNumber(string memory s) internal pure returns (uint256 value) {
        bytes memory b = bytes(s);
        require(b.length > 0, "MGP20Payload: empty number");
        if (b.length > 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X")) {
            for (uint256 i = 2; i < b.length; i++) {
                value = value * 16 + hexDigit(b[i]);
            }
            return value;
        }
        for (uint256 i = 0; i < b.length; i++) {
            require(b[i] >= "0" && b[i] <= "9", "MGP20Payload: not a number");
            value = value * 10 + (uint8(b[i]) - 48);
        }
    }

    function hexDigit(bytes1 c) internal pure returns (uint256) {
        if (c >= "0" && c <= "9") return uint8(c) - 48;
        if (c >= "a" && c <= "f") return uint8(c) - 87;
        if (c >= "A" && c <= "F") return uint8(c) - 55;
        revert("MGP20Payload: not a hex digit");
    }

    /// @notice Strips leading and trailing spaces, tabs and line breaks.
    function trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 start;
        uint256 end = b.length;
        while (start < end && isSpace(b[start])) start++;
        while (end > start && isSpace(b[end - 1])) end--;
        bytes memory out = new bytes(end - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = b[start + i];
        }
        return string(out);
    }

    function isSpace(bytes1 c) internal pure returns (bool) {
        return c == " " || c == "\n" || c == "\r" || c == "\t";
    }
}

/**
 * @title CheckMGP20Payload
 * @notice Read-only gate for the MGP-20 proposal payload. Every check runs against the frozen
 *         `propose` calldata (not a fresh MGP20 computation, which would validate a different
 *         proposal):
 *           1. loads the calldata from `broadcast/MGP20.sol/42220/run-latest.json` (or a raw hex file),
 *           2. binds it to the on-chain proposal (recomputed proposalId must exist on the governor),
 *           3. asserts the 40-call shape against the expected exchange set: the ten USDm/FX pairs
 *              (AUDm, CADm, ZARm, COPm, BRLm, PHPm, GHSm, NGNm, KESm, XOFm) resolved from the treb
 *              addressbook, each matched by asset addresses to exactly one live BiPoolManager exchange,
 *              ten distinct ids, no live exchange outside that set, 18 decimals on USDm and every FX token,
 *           4. verifies that the frozen limits equal the 110% sizing, floored at 10,000 USD, at the
 *              recorded proposal-time block (fork pinned there; the MGP20 run output records the
 *              builder's block and parent hash),
 *           5. reports whether each frozen limit still covers 100% of today's supply / USD equivalent,
 *           6. replays the 40 calls pranked as the timelock on a fork at head and runs the MGP20
 *              post-checks against the frozen values, including the real full-supply swap.
 * @dev Runs as a plain forge script because it manages its own forks:
 *        forge script script/actions/CheckMGP20Payload.s.sol:CheckMGP20Payload -vv
 *      Environment:
 *        MGP20_RPC_URL           RPC to fork (default: CELO_RPC_URL). Pass the anvil URL explicitly on a treb fork.
 *        NAMESPACE               treb registry namespace (default: mainnet).
 *        MGP20_BROADCAST_FILE    broadcast artifact (default: broadcast/MGP20.sol/42220/run-latest.json).
 *        MGP20_CALLDATA_FILE     optional override: a file holding the raw propose calldata as 0x-prefixed hex
 *                                (surrounding whitespace is ignored; the file must live under a path foundry.toml
 *                                allows reading, e.g. broadcast/). There is no receipt to read the target and the
 *                                block from, so this path requires MGP20_PAYLOAD_TARGET and MGP20_SIZING_BLOCK.
 *        MGP20_PAYLOAD_TARGET    with MGP20_CALLDATA_FILE: the address the propose transaction was sent to; it
 *                                must equal the MentoGovernor proxy of the namespace.
 *        MGP20_SIZING_BLOCK      block at which MGP20.sol read supply and rates (default: the propose receipt
 *                                block; required with MGP20_CALLDATA_FILE). Take it from the propose run output.
 *        MGP20_SIZING_SEARCH     how many earlier blocks to try when the sizing block does not match (default: 10).
 */
contract CheckMGP20Payload is Script {
    uint8 internal constant LG = 4;
    uint256 internal constant LIMIT_BUFFER_PCT = 110;
    uint256 internal constant MIN_LIMIT_USD = 10_000e18;
    uint256 internal constant CELO_MAINNET_CHAIN_ID = 42220;

    address internal governor;
    address internal timelock;
    address internal broker;
    address internal biPoolManager;
    address internal usdm;

    /// @dev The ten FX stables whose USDm pairs MGP-20 refreshes (the MGP20.sol pair list).
    string[10] internal expectedFxNames =
        ["AUDm", "CADm", "ZARm", "COPm", "BRLm", "PHPm", "GHSm", "NGNm", "KESm", "XOFm"];
    address[10] internal expectedFx;

    uint256 internal uncovered;

    function run() external {
        string memory rpc = vm.envOr("MGP20_RPC_URL", vm.envOr("CELO_RPC_URL", string("")));
        require(bytes(rpc).length > 0, "set MGP20_RPC_URL or CELO_RPC_URL");
        string memory namespace = vm.envOr("NAMESPACE", string("mainnet"));

        // 1. Load the frozen payload.
        (bytes memory input, address payloadTarget, uint256 proposalBlock, string memory source) = loadPayload();

        uint256 headFork = vm.createSelectFork(rpc);
        require(block.chainid == CELO_MAINNET_CHAIN_ID, "RPC is not Celo mainnet (chain id 42220)");
        resolveAddresses(namespace);

        console.log("== CheckMGP20Payload ==");
        console.log(string.concat("payload source: ", source));
        console.log(
            string.concat(
                "chain id ",
                vm.toString(block.chainid),
                ", head block ",
                vm.toString(block.number),
                ", namespace ",
                namespace
            )
        );
        require(
            payloadTarget == governor,
            "propose transaction target (broadcast transaction.to or MGP20_PAYLOAD_TARGET) is not the MentoGovernor proxy"
        );

        // 2. Decode and bind to the on-chain proposal.
        MGP20Payload.Proposal memory proposal = MGP20Payload.decodePropose(input);
        uint256 proposalId = bindToProposal(proposal);

        // 3. Shape against the expected exchange set.
        console.log("");
        MGP20Payload.ExpectedPool[] memory pools = livePools();
        MGP20Payload.FrozenLimits[] memory frozen = MGP20Payload.validate(proposal, broker, pools);
        console.log(
            unicode" > 🟢 shape: 40 Broker.configureTradingLimit calls, reset-then-set on both legs of the 10 expected exchanges"
        );
        printFrozen(frozen);

        // 4. Exact sizing at the proposal (sizing) block.
        bool operatorBlock = vm.envExists("MGP20_SIZING_BLOCK");
        uint256 sizingBlock = operatorBlock ? vm.envUint("MGP20_SIZING_BLOCK") : proposalBlock;
        uint256 searchWindow = vm.envOr("MGP20_SIZING_SEARCH", uint256(10));
        checkExactSizing(rpc, sizingBlock, operatorBlock, searchWindow, frozen);

        // 5. Coverage at head.
        vm.selectFork(headFork);
        checkCoverage(frozen);

        // 6. Replay as the timelock at head and re-run the post-checks on the frozen values.
        replayAndPostCheck(proposal, frozen);

        console.log("");
        console.log(string.concat("proposal id ", vm.toString(proposalId), ": all checks passed"));
        require(uncovered == 0, "frozen limits no longer cover the current supply of at least one pool, see table");
    }

    /// =========== 1. Payload loading ===========

    function loadPayload()
        internal
        view
        returns (bytes memory input, address target, uint256 proposalBlock, string memory source)
    {
        string memory rawFile = vm.envOr("MGP20_CALLDATA_FILE", string(""));
        if (bytes(rawFile).length > 0) {
            // A raw calldata file carries no receipt: the operator must name the transaction's
            // target (checked against the governor proxy in run()) and the sizing block.
            require(
                vm.envExists("MGP20_PAYLOAD_TARGET"),
                "MGP20_CALLDATA_FILE requires MGP20_PAYLOAD_TARGET (the address the propose transaction was sent to)"
            );
            require(
                vm.envExists("MGP20_SIZING_BLOCK"),
                "MGP20_CALLDATA_FILE requires MGP20_SIZING_BLOCK (the block printed by the MGP20 propose run)"
            );
            input = MGP20Payload.parseCalldataFile(vm.readFile(rawFile));
            target = vm.envAddress("MGP20_PAYLOAD_TARGET");
            proposalBlock = vm.envUint("MGP20_SIZING_BLOCK");
            source = string.concat("raw calldata file ", rawFile, " (target and sizing block operator-supplied)");
            return (input, target, proposalBlock, source);
        }

        string memory path = vm.envOr("MGP20_BROADCAST_FILE", string("broadcast/MGP20.sol/42220/run-latest.json"));
        string memory json = vm.readFile(path);
        require(vm.parseJsonUint(json, ".chain") == CELO_MAINNET_CHAIN_ID, "broadcast artifact is not for chain 42220");
        require(
            keccak256(bytes(vm.parseJsonString(json, ".transactions[0].function")))
                == keccak256("propose(address[],uint256[],bytes[],string)"),
            "transactions[0] is not the propose call"
        );
        target = vm.parseJsonAddress(json, ".transactions[0].transaction.to");
        input = vm.parseJsonBytes(json, ".transactions[0].transaction.input");
        proposalBlock = MGP20Payload.parseNumber(vm.parseJsonString(json, ".receipts[0].blockNumber"));
        source = path;
    }

    /// =========== 2. Binding ===========

    function bindToProposal(MGP20Payload.Proposal memory proposal) internal view returns (uint256 proposalId) {
        proposalId = IGovernorPayload(governor)
            .hashProposal(proposal.targets, proposal.values, proposal.calldatas, keccak256(bytes(proposal.description)));
        uint256 snapshot = IGovernorPayload(governor).proposalSnapshot(proposalId);
        require(snapshot != 0, "recomputed proposal id does not exist on the governor: stale or edited payload");

        console.log("");
        console.log(string.concat("proposal id:       ", vm.toString(proposalId)));
        console.log(string.concat("snapshot block:    ", vm.toString(snapshot)));
        console.log(
            string.concat("deadline block:    ", vm.toString(IGovernorPayload(governor).proposalDeadline(proposalId)))
        );
        console.log(string.concat("state:             ", stateName(IGovernorPayload(governor).state(proposalId))));
        console.log(string.concat("description bytes: ", vm.toString(bytes(proposal.description).length)));
        console.log(unicode" > 🟢 payload is bound to an existing on-chain proposal");
    }

    /// =========== 3. Expected exchange set ===========

    /// @dev Builds the expected pool set the payload must cover, the same way MGP20.sol resolves
    ///      its pairs: for each of the ten intended FX stables (addresses from the treb
    ///      addressbook, see resolveAddresses) exactly one live BiPoolManager exchange must pair
    ///      it with USDm (zero or duplicate matches are rejected), the ten resolved ids must be
    ///      distinct, every live exchange must belong to that set (so an unexpected eleventh
    ///      pool, or a missing one, fails here rather than in the shape check), and USDm and every
    ///      FX token must report 18 decimals on the fork this runs on (the USD conversion in the
    ///      sizing check assumes equal scales). Exchange ids are matched by asset addresses only;
    ///      on-chain ids were hashed from since-renamed symbols and cannot be recomputed.
    function livePools() internal view returns (MGP20Payload.ExpectedPool[] memory pools) {
        bytes32[] memory ids = IBiPoolManager(biPoolManager).getExchangeIds();
        require(
            ids.length == MGP20Payload.POOL_COUNT,
            string.concat("BiPoolManager does not hold exactly 10 exchanges, found ", vm.toString(ids.length))
        );
        require(IERC20Metadata(usdm).decimals() == 18, "USDm is not 18 decimals");

        pools = new MGP20Payload.ExpectedPool[](expectedFx.length);
        bool[] memory claimed = new bool[](ids.length);
        for (uint256 p = 0; p < expectedFx.length; p++) {
            address fx = expectedFx[p];
            string memory pair = string.concat("USDm/", expectedFxNames[p]);
            require(IERC20Metadata(fx).decimals() == 18, string.concat(expectedFxNames[p], " is not 18 decimals"));

            uint256 matches;
            uint256 matched;
            for (uint256 i = 0; i < ids.length; i++) {
                IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(ids[i]);
                bool assetsMatch =
                    (pool.asset0 == usdm && pool.asset1 == fx) || (pool.asset0 == fx && pool.asset1 == usdm);
                if (assetsMatch) {
                    matches++;
                    matched = i;
                }
            }
            require(matches > 0, string.concat("no live exchange for ", pair));
            require(matches == 1, string.concat("more than one live exchange for ", pair));
            require(!claimed[matched], string.concat("duplicate exchange id for ", pair));
            claimed[matched] = true;

            pools[p] = MGP20Payload.ExpectedPool({exchangeId: ids[matched], fxToken: fx, usdmToken: usdm});
        }

        for (uint256 i = 0; i < ids.length; i++) {
            require(claimed[i], string.concat("live exchange outside the expected USDm/FX set: ", vm.toString(ids[i])));
        }
        console.log(
            unicode" > 🟢 expected set: 10 USDm/FX pairs resolved from the addressbook, each exactly one live exchange, 10 distinct ids, 18-decimal tokens"
        );
    }

    function printFrozen(MGP20Payload.FrozenLimits[] memory frozen) internal view {
        console.log("");
        console.log("| # | Pool | Exchange ID | FX LG frozen | USDm LG frozen |");
        console.log("| --- | --- | --- | ---: | ---: |");
        for (uint256 i = 0; i < frozen.length; i++) {
            string memory row = cell("| ", vm.toString(i));
            row = cell(row, pairLabel(frozen[i]));
            row = cell(row, vm.toString(frozen[i].exchangeId));
            row = cell(row, whole(frozen[i].fxLimit));
            row = cell(row, whole(frozen[i].usdmLimit));
            console.log(row);
        }
    }

    /// =========== 4. Exact sizing ===========

    /// @dev Pins a fork at `sizingBlock`, recomputes the MGP-18/20 sizing for every pool and
    ///      requires equality with the frozen limits. MGP20.sol reads state in the forge
    ///      simulation a few blocks before the propose transaction is mined, so when the
    ///      receipt block does not match, up to `searchWindow` earlier blocks are tried and the
    ///      matching block is reported. A match shows that the frozen limits equal the sizing at
    ///      a state equivalent to the builder's; which block the builder actually used is recorded
    ///      by the MGP20 run output (block and parent hash), and can be passed as
    ///      MGP20_SIZING_BLOCK (`operatorBlock`). If nothing matches, the per-pool differences at
    ///      `sizingBlock` are printed and the check fails.
    function checkExactSizing(
        string memory rpc,
        uint256 sizingBlock,
        bool operatorBlock,
        uint256 searchWindow,
        MGP20Payload.FrozenLimits[] memory frozen
    ) internal {
        console.log("");
        console.log(
            string.concat(
                "== Exact sizing check (starting at block ",
                vm.toString(sizingBlock),
                operatorBlock
                    ? ", operator-supplied via MGP20_SIZING_BLOCK"
                    : ", the propose receipt block from the broadcast artifact",
                ") =="
            )
        );

        for (uint256 back = 0; back <= searchWindow; back++) {
            uint256 blockNumber = sizingBlock - back;
            vm.createSelectFork(rpc, blockNumber);
            uint256 mismatches = countSizingMismatches(frozen, back == 0);
            if (mismatches == 0) {
                console.log(
                    string.concat(
                        unicode" > 🟢 all 20 frozen limits equal the 110% sizing (10,000 USD floor) at block ",
                        vm.toString(blockNumber),
                        back == 0 ? "" : string.concat(" (", vm.toString(back), " blocks before the starting block)"),
                        " (equivalent sizing state; the MGP20 run output records the builder's block)"
                    )
                );
                return;
            }
        }

        revert(
            "frozen limits do not equal the 110% sizing (10,000 USD floor) at the proposal block; pass MGP20_SIZING_BLOCK=<block printed by the propose run>"
        );
    }

    function countSizingMismatches(MGP20Payload.FrozenLimits[] memory frozen, bool verbose)
        internal
        view
        returns (uint256 mismatches)
    {
        if (verbose) {
            console.log(
                "| Pool | block | FX supply | rate fraction | FX LG recomputed | FX LG frozen | USDm LG recomputed | USDm LG frozen | match |"
            );
            console.log("| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- |");
        }
        for (uint256 i = 0; i < frozen.length; i++) {
            Sizing memory s = sizeLimits(frozen[i], LIMIT_BUFFER_PCT, MIN_LIMIT_USD);
            bool ok = s.fxLimit == frozen[i].fxLimit && s.usdmLimit == frozen[i].usdmLimit;
            if (!ok) mismatches++;
            if (verbose) console.log(sizingRow(frozen[i], s, ok));
        }
    }

    function sizingRow(MGP20Payload.FrozenLimits memory f, Sizing memory s, bool ok)
        internal
        view
        returns (string memory row)
    {
        row = cell("| ", pairLabel(f));
        row = cell(row, vm.toString(block.number));
        row = cell(row, groupDigits(s.supply / 1e18));
        row = cell(row, string.concat(vm.toString(s.rateNumerator), "/", vm.toString(s.rateDenominator)));
        row = cell(row, whole(s.fxLimit));
        row = cell(row, whole(f.fxLimit));
        row = cell(row, whole(s.usdmLimit));
        row = cell(row, whole(f.usdmLimit));
        row = cell(row, ok ? "yes" : unicode"❌ NO");
    }

    struct Sizing {
        int48 fxLimit;
        int48 usdmLimit;
        uint256 supply;
        uint256 rateNumerator;
        uint256 rateDenominator;
    }

    /// @dev Independent re-derivation of MGP20.getProposedLimits: buffered supply floored in wei,
    ///      USD equivalent at the pool's reference rate, both raised to `minUsd` (and its FX
    ///      equivalent, rounded up in wei) when worth less, then rounded up to whole tokens. With
    ///      bufferPct = 100 and minUsd = 0 it yields the 100% requirement used by the coverage check.
    function sizeLimits(MGP20Payload.FrozenLimits memory f, uint256 bufferPct, uint256 minUsd)
        internal
        view
        returns (Sizing memory s)
    {
        s.supply = IERC20Metadata(f.fxToken).totalSupply();
        uint256 fxAmount = (s.supply * bufferPct) / 100;

        IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(f.exchangeId);
        (s.rateNumerator, s.rateDenominator) =
            IBiPoolManager(biPoolManager).sortedOracles().medianRate(pool.config.referenceRateFeedID);
        require(s.rateNumerator > 0 && s.rateDenominator > 0, "no oracle rate for exchange");

        uint256 usdmEquivalent = (fxAmount * s.rateNumerator) / s.rateDenominator;
        if (usdmEquivalent < minUsd) {
            usdmEquivalent = minUsd;
            fxAmount = (minUsd * s.rateDenominator + s.rateNumerator - 1) / s.rateNumerator;
        }
        s.fxLimit = toWholeTokenLimit(fxAmount, IERC20Metadata(f.fxToken).decimals());
        s.usdmLimit = toWholeTokenLimit(usdmEquivalent, IERC20Metadata(f.usdmToken).decimals());
    }

    function toWholeTokenLimit(uint256 amount, uint8 decimals) internal pure returns (int48) {
        uint256 unit = 10 ** uint256(decimals);
        uint256 wholeTokens = (amount + unit - 1) / unit;
        require(wholeTokens <= uint256(uint48(type(int48).max)), "limit does not fit int48");
        return int48(uint48(wholeTokens));
    }

    /// =========== 5. Coverage at head ===========

    function checkCoverage(MGP20Payload.FrozenLimits[] memory frozen) internal {
        console.log("");
        console.log(
            string.concat(
                "== Coverage at head (chain id ",
                vm.toString(block.chainid),
                ", block ",
                vm.toString(block.number),
                "): frozen LG vs 100% of current supply / USD equivalent =="
            )
        );
        console.log(
            "| Pool | FX supply now | FX required (100%) | FX LG frozen | FX headroom | USDm required (100%) | USDm LG frozen | USDm headroom | covered |"
        );
        console.log("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |");

        uncovered = 0;
        for (uint256 i = 0; i < frozen.length; i++) {
            Sizing memory required = sizeLimits(frozen[i], 100, 0);
            bool covered = frozen[i].fxLimit >= required.fxLimit && frozen[i].usdmLimit >= required.usdmLimit;
            if (!covered) uncovered++;
            console.log(coverageRow(frozen[i], required, covered));
        }

        if (uncovered == 0) {
            console.log(unicode" > 🟢 every frozen limit covers 100% of the current supply and its USD equivalent");
        } else {
            console.log(unicode" > ❌ %s pool(s) no longer covered by the frozen limits", uncovered);
        }
    }

    function coverageRow(MGP20Payload.FrozenLimits memory f, Sizing memory required, bool covered)
        internal
        view
        returns (string memory row)
    {
        row = cell("| ", pairLabel(f));
        row = cell(row, groupDigits(required.supply / 1e18));
        row = cell(row, whole(required.fxLimit));
        row = cell(row, whole(f.fxLimit));
        row = cell(row, formatSigned(int256(f.fxLimit) - int256(required.fxLimit)));
        row = cell(row, whole(required.usdmLimit));
        row = cell(row, whole(f.usdmLimit));
        row = cell(row, formatSigned(int256(f.usdmLimit) - int256(required.usdmLimit)));
        row = cell(row, covered ? "yes" : unicode"❌ NO");
    }

    /// =========== 6. Replay ===========

    function replayAndPostCheck(MGP20Payload.Proposal memory proposal, MGP20Payload.FrozenLimits[] memory frozen)
        internal
    {
        console.log("");
        console.log(
            string.concat(
                "== Replay as timelock ", vm.toString(timelock), " at block ", vm.toString(block.number), " =="
            )
        );

        vm.startPrank(timelock);
        for (uint256 i = 0; i < proposal.calldatas.length; i++) {
            (bool success, bytes memory ret) =
                proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            if (!success) {
                console.log(string.concat("call #", vm.toString(i), " reverted"));
                console.logBytes(ret);
                revert(string.concat("replay failed at call #", vm.toString(i)));
            }
        }
        vm.stopPrank();
        console.log(unicode" > 🟢 40 calls applied in order");

        for (uint256 i = 0; i < frozen.length; i++) {
            string memory pair = pairLabel(frozen[i]);
            checkGlobalOnlyLimit(pair, "USDm", frozen[i].exchangeId, frozen[i].usdmToken, frozen[i].usdmLimit);
            checkGlobalOnlyLimit(pair, "FX", frozen[i].exchangeId, frozen[i].fxToken, frozen[i].fxLimit);
            (uint256 fxSupply, uint256 amountOut) =
                checkSupplyCanExit(frozen[i].exchangeId, frozen[i].usdmToken, frozen[i].fxToken);
            string memory line =
                string.concat(pair, unicode" ✅ LG-only with frozen values, netflow zero, full supply exits (");
            line = string.concat(
                line, groupDigits(fxSupply / 1e18), " in -> ", groupDigits(amountOut / 1e18), " USDm out)"
            );
            console.log(line);
        }
    }

    function checkGlobalOnlyLimit(
        string memory pair,
        string memory asset,
        bytes32 exchangeId,
        address token,
        int48 expectedLimitGlobal
    ) internal view {
        bytes32 id = exchangeId ^ bytes32(uint256(uint160(token)));
        (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags) =
            IBrokerTradingLimits(broker).tradingLimitsConfig(id);
        (,,,, int48 netflowGlobal) = IBrokerTradingLimits(broker).tradingLimitsState(id);

        string memory label = string.concat(asset, " on ", pair);
        require(flags == LG, string.concat("flags not LG-only for ", label));
        require(limitGlobal == expectedLimitGlobal, string.concat("limitGlobal differs from frozen value for ", label));
        require(limit0 == 0 && timestep0 == 0, string.concat("L0 config not cleared for ", label));
        require(limit1 == 0 && timestep1 == 0, string.concat("L1 config not cleared for ", label));
        require(netflowGlobal == 0, string.concat("netflowGlobal not reset for ", label));
    }

    /// @dev Same real-swap probe as MGP20.checkSupplyCanExit: mint the full FX supply to a prober
    ///      (pranking the Broker) and swap it to USDm through the Broker, inside a state snapshot.
    function checkSupplyCanExit(bytes32 exchangeId, address usdmToken, address fxToken)
        internal
        returns (uint256 fxSupply, uint256 amountOut)
    {
        uint256 snapshot = vm.snapshotState();

        fxSupply = IERC20Metadata(fxToken).totalSupply();
        address prober = makeAddr("mgp20-payload-prober");

        vm.prank(broker);
        IStableTokenV2(fxToken).mint(prober, fxSupply);

        vm.startPrank(prober);
        IERC20Metadata(fxToken).approve(broker, fxSupply);
        amountOut = IBroker(broker).swapIn(biPoolManager, exchangeId, fxToken, usdmToken, fxSupply, 0);
        vm.stopPrank();

        vm.revertToState(snapshot);
    }

    /// =========== Helpers ===========

    /// @dev Resolves the proxies from the treb registry files the way treb-sol's Registry does
    ///      (`.<chainId>.<namespace>["<id>"]` in .treb/registry.json, then `.<chainId>["<id>"]` in
    ///      .treb/addressbook.json), but parses the JSON in memory instead of deploying a Registry
    ///      contract: the registry JSON is ~80 KB and storing it on-chain exceeds the 30M gas that
    ///      a CREATE gets under forge's isolated execution.
    function resolveAddresses(string memory namespace) internal {
        string memory registryJson = vm.readFile(".treb/registry.json");
        string memory addressbookJson = vm.readFile(".treb/addressbook.json");
        string memory chainId = vm.toString(block.chainid);

        governor = lookupOrFail(
            registryJson, addressbookJson, chainId, namespace, "TransparentUpgradeableProxy:MentoGovernor"
        );
        timelock = lookupOrFail(
            registryJson, addressbookJson, chainId, namespace, "TransparentUpgradeableProxy:TimelockController"
        );
        broker = lookupOrFail(registryJson, addressbookJson, chainId, namespace, "Proxy:Broker");
        biPoolManager = lookupOrFail(registryJson, addressbookJson, chainId, namespace, "Proxy:BiPoolManager");
        usdm = lookupOrFail(registryJson, addressbookJson, chainId, namespace, "Proxy:USDm");
        for (uint256 i = 0; i < expectedFxNames.length; i++) {
            expectedFx[i] = lookupOrFail(
                registryJson, addressbookJson, chainId, namespace, string.concat("Proxy:", expectedFxNames[i])
            );
            require(expectedFx[i] != usdm, string.concat(expectedFxNames[i], " resolves to the USDm proxy"));
            for (uint256 j = 0; j < i; j++) {
                require(
                    expectedFx[j] != expectedFx[i],
                    string.concat(expectedFxNames[i], " resolves to the same proxy as ", expectedFxNames[j])
                );
            }
        }
        require(IGovernorPayload(governor).timelock() == timelock, "governor timelock differs from registry");
    }

    function lookupOrFail(
        string memory registryJson,
        string memory addressbookJson,
        string memory chainId,
        string memory namespace,
        string memory identifier
    ) internal view returns (address addr) {
        string memory registryPath = string.concat(".", chainId, ".", namespace, '["', identifier, '"]');
        if (vm.keyExistsJson(registryJson, registryPath)) {
            addr = vm.parseJsonAddress(registryJson, registryPath);
        } else {
            string memory addressbookPath = string.concat(".", chainId, '["', identifier, '"]');
            if (vm.keyExistsJson(addressbookJson, addressbookPath)) {
                addr = vm.parseJsonAddress(addressbookJson, addressbookPath);
            }
        }
        require(addr != address(0), string.concat(identifier, " not found in .treb registry or addressbook"));
    }

    /// @dev Appends one markdown table cell.
    function cell(string memory row, string memory value) internal pure returns (string memory) {
        return string.concat(row, value, " | ");
    }

    function whole(int48 limit) internal pure returns (string memory) {
        return groupDigits(uint256(int256(limit)));
    }

    function pairLabel(MGP20Payload.FrozenLimits memory f) internal view returns (string memory) {
        return string.concat(safeSymbol(f.usdmToken), "/", safeSymbol(f.fxToken));
    }

    function safeSymbol(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return vm.toString(token);
        }
    }

    function stateName(uint8 state) internal pure returns (string memory) {
        string[8] memory names =
            ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];
        return state < 8 ? names[state] : "Unknown";
    }

    function formatSigned(int256 value) internal pure returns (string memory) {
        if (value < 0) return string.concat("-", groupDigits(uint256(-value)));
        return groupDigits(uint256(value));
    }

    /// @dev Formats a number with `_` thousands separators, e.g. 1000000 -> "1_000_000".
    function groupDigits(uint256 value) internal pure returns (string memory) {
        bytes memory digits = bytes(vm.toString(value));
        if (digits.length <= 3) return string(digits);

        bytes memory out = new bytes(digits.length + (digits.length - 1) / 3);
        uint256 j = out.length;
        for (uint256 i = 0; i < digits.length; i++) {
            if (i > 0 && i % 3 == 0) out[--j] = "_";
            out[--j] = digits[digits.length - 1 - i];
        }
        return string(out);
    }
}
