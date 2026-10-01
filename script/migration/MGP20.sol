// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IStableTokenV2} from "lib/mento-core/contracts/interfaces/IStableTokenV2.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

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
 * @title MGP20
 * @notice Refreshes the global-only (LG) trading limits that MGP-18 put on the ten USDm/FX
 *         exchanges remaining in Mento v2. MGP-18 sized those limits at the 31 August 2026
 *         supply. Supply has moved since: AUDm has consumed its limit on both legs (so
 *         USDm -> AUDm swaps revert), while XOFm and KESm shrank and sit far below their caps.
 *         Each pair is re-sized with the MGP-18 method from live state at proposal creation:
 *           - FX asset:  the FX token's current total supply x 1.1, rounded up to whole tokens, and
 *           - USDm:      the USD equivalent of that amount at the current oracle rate x 1.1.
 *         Each limit is first reset (configured with no flags, clearing the accumulated
 *         netflowGlobal) and then set to the new global-only value, so the new limits apply
 *         from a clean slate rather than on top of historical netflow. The reset is the safety
 *         mechanism, not cleanup: a pool whose cap shrinks below its accumulated netflow (XOFm)
 *         would be bricked by setting the smaller limit directly.
 *         The sizing arithmetic is copied from MGP18.sol unchanged (see getProposedLimits);
 *         the pre- and post-checks are stricter than MGP-18's.
 */
contract MGP20 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    uint8 internal constant LG = 4;

    /// @dev The ten USDm/FX exchanges left after the migration multisig destroyed the
    ///      collateral and 1:1 pools that followed MGP-18. Anything else is unexpected.
    uint256 internal constant EXPECTED_EXCHANGE_COUNT = 10;

    /// @dev Buffer applied to both limits (1.1x) to absorb supply drift between proposal
    ///      creation and execution; see getProposedLimits.
    uint256 internal constant LIMIT_BUFFER_PCT = 110;

    /// @param asset0 Registry name of the exchange's first asset (USDm).
    /// @param asset1 Registry name of the exchange's second asset (the FX stable).
    /// @param limitGlobal0 Proposed global limit for asset0, computed on-chain in preChecks.
    /// @param limitGlobal1 Proposed global limit for asset1, computed on-chain in preChecks.
    struct LimitUpdate {
        string asset0;
        string asset1;
        int48 limitGlobal0;
        int48 limitGlobal1;
    }

    /// @dev Live state of one exchange, captured in preChecks before anything changes and
    ///      reused by applyLimits (so the calls target exactly the checked exchange) and by
    ///      the evidence table.
    struct PoolState {
        bytes32 exchangeId;
        address token0; // USDm
        address token1; // FX stable
        uint256 fxSupply;
        int48 currentLimit0;
        int48 currentLimit1;
        int48 netflow0;
        int48 netflow1;
        uint256 rateNumerator;
        uint256 rateDenominator;
    }

    address internal brokerProxy;
    address internal biPoolManagerProxy;
    IMentoConfig internal config;
    LimitUpdate[] internal updates;
    PoolState[] internal pools;

    uint256 internal limitsRaised;
    uint256 internal limitsReduced;
    uint256 internal limitsUnchanged;

    function setUp() public {
        brokerProxy = lookupProxyOrFail("Broker", ProxyType.CELO);
        biPoolManagerProxy = lookupProxyOrFail("BiPoolManager", ProxyType.CELO);
        config = Config.get();

        updates.push(LimitUpdate("USDm", "AUDm", 0, 0));
        updates.push(LimitUpdate("USDm", "CADm", 0, 0));
        updates.push(LimitUpdate("USDm", "ZARm", 0, 0));
        updates.push(LimitUpdate("USDm", "COPm", 0, 0));
        updates.push(LimitUpdate("USDm", "BRLm", 0, 0));
        updates.push(LimitUpdate("USDm", "PHPm", 0, 0));
        updates.push(LimitUpdate("USDm", "GHSm", 0, 0));
        updates.push(LimitUpdate("USDm", "NGNm", 0, 0));
        updates.push(LimitUpdate("USDm", "KESm", 0, 0));
        updates.push(LimitUpdate("USDm", "XOFm", 0, 0));
    }

    /// @custom:senders deployer, governor
    function run() public virtual broadcast {
        Senders.Sender storage govSender = sender("governor");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-20: Refresh trading limits on remaining Mento v2 exchanges");
        ozGovSender.setProposalDescription("./mgps/mgp20.md");

        preChecks();

        applyLimits(govSender);

        postChecks();
    }

    function applyLimits(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Applying supply-based global-only trading limits ==");

        for (uint256 i = 0; i < updates.length; i++) {
            LimitUpdate storage update = updates[i];
            PoolState storage pool = pools[i];
            string memory pair = string.concat(update.asset0, "/", update.asset1);
            require(update.limitGlobal0 > 0 && update.limitGlobal1 > 0, string.concat("limits not computed for ", pair));

            console.log(string.concat("Exchange (", pair, ")"));
            console.log(string.concat("   current ", update.asset1, " supply: ", groupDigits(pool.fxSupply / 1e18)));

            console.log(
                string.concat(
                    "   ...resetting netflow and setting ",
                    update.asset1,
                    " limit to global-only ",
                    groupDigits(uint256(int256(update.limitGlobal1)))
                )
            );
            resetAndSetGlobalLimit(govSender, pool.exchangeId, pool.token1, update.limitGlobal1);

            console.log(
                string.concat(
                    "   ...resetting netflow and setting ",
                    update.asset0,
                    " limit to global-only ",
                    groupDigits(uint256(int256(update.limitGlobal0))),
                    " (@ ",
                    formatRate(pool.rateNumerator, pool.rateDenominator),
                    " ",
                    update.asset1,
                    "/USD)"
                )
            );
            resetAndSetGlobalLimit(govSender, pool.exchangeId, pool.token0, update.limitGlobal0);
        }
    }

    /// @notice Computes the proposed global limits for an exchange:
    ///         the FX token's current total supply (whole tokens, rounded up) and its USD
    ///         equivalent at the current oracle rate, both scaled by LIMIT_BUFFER. The USDm
    ///         value is a snapshot, so later FX appreciation can consume the buffer and require
    ///         governance to raise the USDm limit. Trading limits are denominated in whole tokens:
    ///         the Broker divides amounts by 10^decimals before applying them.
    /// @dev The oracle rate feeds for the FX exchanges ({CUR}USD) report USD per FX unit —
    ///      the same direction the BiPoolManager uses to derive the FX bucket from the USDm
    ///      bucket in getUpdatedBuckets.
    /// @dev Arithmetic kept byte-for-byte identical to MGP18.getProposedLimits on purpose. The
    ///      engineering handoff writes the 110% step as a ceiling; this implementation floors it
    ///      in wei (integer division) and only rounds up when converting to whole tokens. The
    ///      difference is at most 1 wei in the buffered FX amount and a few wei in the USD
    ///      equivalent, which can only change a whole-token limit when the amount sits within
    ///      those wei of a 10^18 boundary. The deviation is accepted; do not "fix" it here.
    function getProposedLimits(bytes32 exchangeId, address usdmToken, address fxToken)
        internal
        view
        returns (int48 usdmLimit, int48 fxLimit, uint256 rateNumerator, uint256 rateDenominator)
    {
        // The limits are frozen into the proposal calldata now, but the supply keeps moving
        // until the proposal executes after the voting/timelock window. If the supply grows in
        // between, a 1x limit would leave the excess unable to exit back to USDm. The 10%
        // buffer absorbs moderate combined supply and exchange-rate drift, at the cost of adding
        // the same margin to the minting headroom. It is not a permanent exchange-rate guarantee.
        uint256 fxSupply = (IERC20Metadata(fxToken).totalSupply() * LIMIT_BUFFER_PCT) / 100;

        IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
        (rateNumerator, rateDenominator) =
            IBiPoolManager(biPoolManagerProxy).sortedOracles().medianRate(pool.config.referenceRateFeedID);
        require(rateNumerator > 0 && rateDenominator > 0, "no oracle rate for exchange");

        uint256 usdmEquivalent = (fxSupply * rateNumerator) / rateDenominator;

        fxLimit = toWholeTokenLimit(fxSupply, IERC20Metadata(fxToken).decimals());
        usdmLimit = toWholeTokenLimit(usdmEquivalent, IERC20Metadata(usdmToken).decimals());
    }

    /// @dev Converts a token amount to a whole-token limit, rounding up so the full amount
    ///      always fits within the limit.
    function toWholeTokenLimit(uint256 amount, uint8 decimals) internal pure returns (int48) {
        uint256 unit = 10 ** uint256(decimals);
        uint256 wholeTokens = (amount + unit - 1) / unit;
        require(wholeTokens <= uint256(uint48(type(int48).max)), "limit does not fit int48");
        return int48(uint48(wholeTokens));
    }

    /// @dev Resets the accumulated netflow, then sets the new global-only limit.
    ///      configureTradingLimit preserves netflowGlobal while the LG flag stays set, so the
    ///      state is first cleared with an empty config (no flags -> all netflows zeroed).
    function resetAndSetGlobalLimit(
        Senders.Sender storage govSender,
        bytes32 exchangeId,
        address token,
        int48 limitGlobal
    ) internal {
        ITradingLimits.Config memory reset;
        IBroker(govSender.harness(brokerProxy)).configureTradingLimit(exchangeId, token, reset);

        ITradingLimits.Config memory config_;
        config_.limitGlobal = limitGlobal;
        config_.flags = LG;
        IBroker(govSender.harness(brokerProxy)).configureTradingLimit(exchangeId, token, config_);
    }

    /// =========== Proposal checks ===========

    /// @dev Before: the BiPoolManager must hold exactly the ten expected exchanges; every
    ///      configured pair must match exactly one live exchange, the ten ids must be distinct,
    ///      both assets must have 18 decimals, the pool's rate feed must be the one this repo's
    ///      config expects for the pair (with a nonzero median), and both legs must still carry
    ///      the MGP-18 limit shape (LG only, L0/L1 and timesteps zero, positive limitGlobal).
    ///      Captures the live state and the proposed limits, then prints them as a table.
    function preChecks() internal {
        console.log("== Pre-checks ==");
        console.log(
            string.concat(
                "chain id ",
                vm.toString(block.chainid),
                ", block ",
                vm.toString(block.number),
                ", timestamp ",
                vm.toString(block.timestamp)
            )
        );

        bytes32[] memory ids = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
        require(
            ids.length == EXPECTED_EXCHANGE_COUNT,
            string.concat("expected exactly 10 live exchanges, found ", vm.toString(ids.length))
        );
        console.log(unicode" > 🟢 BiPoolManager holds exactly %s exchanges", ids.length);

        delete pools;
        for (uint256 i = 0; i < updates.length; i++) {
            checkPool(i);
        }

        printProposedLimits();
    }

    /// @dev Pre-checks one configured pair and records its live state and proposed limits.
    function checkPool(uint256 i) internal {
        LimitUpdate storage update = updates[i];
        string memory pair = string.concat(update.asset0, "/", update.asset1);

        (address token0, address token1, bytes32 exchangeId) = checkExchange(update, pair);
        checkRateFeed(pair, exchangeId);
        recordPool(i, pair, token0, token1, exchangeId);

        console.log(
            unicode" > 🟢 %s: unique live exchange, 18-decimal assets, expected rate feed, MGP-18 limit shape on both assets",
            pair
        );
    }

    /// @dev Exactly one live exchange must pair the two assets, its id must not have been
    ///      claimed by an earlier pair, and both assets must have 18 decimals (the USD
    ///      conversion assumes equal scales).
    function checkExchange(LimitUpdate storage update, string memory pair)
        internal
        view
        returns (address token0, address token1, bytes32 exchangeId)
    {
        uint256 matches;
        (token0, token1, exchangeId, matches) = resolve(update);
        require(matches > 0, string.concat("no live exchange for ", pair));
        require(matches == 1, string.concat("more than one live exchange for ", pair));
        for (uint256 j = 0; j < pools.length; j++) {
            require(pools[j].exchangeId != exchangeId, string.concat("duplicate exchange id for ", pair));
        }

        require(IERC20Metadata(token0).decimals() == 18, string.concat(update.asset0, " is not 18 decimals on ", pair));
        require(IERC20Metadata(token1).decimals() == 18, string.concat(update.asset1, " is not 18 decimals on ", pair));
    }

    /// @dev The pool's reference rate feed must be the one this repo's config expects for the
    ///      pair, so the USD conversion really uses the FX/USD feed of that currency.
    function checkRateFeed(string memory pair, bytes32 exchangeId) internal view {
        IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
        (IMentoConfig.ExchangeConfig memory cfg, bool found) =
            config.getExchangeConfig(pool.asset0, pool.asset1, address(pool.pricingModule));
        require(found, string.concat("no config entry for ", pair));
        require(
            cfg.pool.config.referenceRateFeedID == pool.config.referenceRateFeedID,
            string.concat("unexpected reference rate feed for ", pair)
        );
    }

    /// @dev Requires the MGP-18 shape on both legs, computes the proposed limits from live state
    ///      and stores everything for applyLimits, postChecks and the evidence table.
    function recordPool(uint256 i, string memory pair, address token0, address token1, bytes32 exchangeId) internal {
        LimitUpdate storage update = updates[i];
        PoolState memory state;
        state.exchangeId = exchangeId;
        state.token0 = token0;
        state.token1 = token1;
        state.fxSupply = IERC20Metadata(token1).totalSupply();

        (state.currentLimit0, state.netflow0) = checkMgp18Shape(pair, update.asset0, exchangeId, token0);
        (state.currentLimit1, state.netflow1) = checkMgp18Shape(pair, update.asset1, exchangeId, token1);
        (update.limitGlobal0, update.limitGlobal1, state.rateNumerator, state.rateDenominator) =
            getProposedLimits(exchangeId, token0, token1);

        pools.push(state);
    }

    /// @dev Requires the MGP-18 limit shape on one leg and returns its current LG and netflow.
    function checkMgp18Shape(string memory pair, string memory asset, bytes32 exchangeId, address token)
        internal
        view
        returns (int48 limitGlobal, int48 netflowGlobal)
    {
        bytes32 id = limitId(exchangeId, token);
        (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 lg, uint8 flags) =
            IBrokerTradingLimits(brokerProxy).tradingLimitsConfig(id);
        (,,,, int48 netflow) = IBrokerTradingLimits(brokerProxy).tradingLimitsState(id);

        string memory label = string.concat(asset, " on ", pair);
        require(flags == LG, string.concat("flags not LG-only (MGP-18 shape) for ", label));
        require(limit0 == 0 && timestep0 == 0, string.concat("L0 config present for ", label));
        require(limit1 == 0 && timestep1 == 0, string.concat("L1 config present for ", label));
        require(lg > 0, string.concat("limitGlobal not positive for ", label));

        return (lg, netflow);
    }

    /// @dev Prints the before/after table (copy-pasteable markdown) and the raised/reduced summary.
    function printProposedLimits() internal {
        console.log("");
        console.log(
            string.concat(
                "== Proposed limits (chain id ",
                vm.toString(block.chainid),
                ", block ",
                vm.toString(block.number),
                "; whole tokens; netflow from the pool's perspective, negative = flowed out to users) =="
            )
        );
        console.log(
            "| Pool | FX supply | FX LG now | FX netflowGlobal | FX LG proposed | FX leg | USDm LG now | USDm netflowGlobal | USDm LG proposed | USDm leg | rate (USD per FX) | rate fraction |"
        );
        console.log("| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | ---: | --- |");

        limitsRaised = 0;
        limitsReduced = 0;
        limitsUnchanged = 0;
        for (uint256 i = 0; i < updates.length; i++) {
            console.log(tableRow(i));
            countDirection(updates[i].limitGlobal1, pools[i].currentLimit1);
            countDirection(updates[i].limitGlobal0, pools[i].currentLimit0);
        }

        console.log("");
        console.log(summary());
    }

    function tableRow(uint256 i) internal view returns (string memory) {
        LimitUpdate storage update = updates[i];
        PoolState storage pool = pools[i];

        string memory fxLeg = string.concat(
            groupDigits(pool.fxSupply / 1e18),
            " | ",
            formatSigned(pool.currentLimit1),
            " | ",
            formatSigned(pool.netflow1),
            " | ",
            formatSigned(update.limitGlobal1),
            " | ",
            direction(update.limitGlobal1, pool.currentLimit1)
        );
        string memory usdmLeg = string.concat(
            formatSigned(pool.currentLimit0),
            " | ",
            formatSigned(pool.netflow0),
            " | ",
            formatSigned(update.limitGlobal0),
            " | ",
            direction(update.limitGlobal0, pool.currentLimit0)
        );
        string memory rate = string.concat(
            formatRate(pool.rateNumerator, pool.rateDenominator),
            " | ",
            vm.toString(pool.rateNumerator),
            "/",
            vm.toString(pool.rateDenominator)
        );
        return string.concat("| ", update.asset0, "/", update.asset1, " | ", fxLeg, " | ", usdmLeg, " | ", rate, " |");
    }

    function countDirection(int48 proposed, int48 current) internal {
        if (proposed > current) limitsRaised++;
        else if (proposed < current) limitsReduced++;
        else limitsUnchanged++;
    }

    function summary() internal view returns (string memory) {
        return string.concat(
            "Summary: ",
            vm.toString(limitsRaised),
            " limits raised, ",
            vm.toString(limitsReduced),
            " reduced, ",
            vm.toString(limitsUnchanged),
            " unchanged (",
            vm.toString(updates.length * 2),
            " limits on ",
            vm.toString(updates.length),
            " exchanges)"
        );
    }

    /// @dev After: every configured pair must have a global-only limit on both assets (no L0,
    ///      no L1, only LG with the expected value) with a reset netflowGlobal, and the FX
    ///      token's entire supply must be swappable back to USDm under the new limits at the
    ///      current oracle rate.
    function postChecks() internal {
        console.log("");
        console.log("== Post-checks ==");

        for (uint256 i = 0; i < updates.length; i++) {
            LimitUpdate memory update = updates[i];
            PoolState memory pool = pools[i];
            string memory pair = string.concat(update.asset0, "/", update.asset1);

            checkGlobalOnlyLimit(pair, update.asset0, pool.exchangeId, pool.token0, update.limitGlobal0);
            checkGlobalOnlyLimit(pair, update.asset1, pool.exchangeId, pool.token1, update.limitGlobal1);
            (uint256 fxSupply, uint256 amountOut) = checkSupplyCanExit(pool.exchangeId, pool.token0, pool.token1);

            console.log(string.concat(pair, unicode" ✅"));
            console.log("   ...global-only limits set on both assets");
            console.log("   ...netflowGlobal reset to zero on both assets");
            console.log(
                string.concat(
                    "   ...full supply can exit to USDm (",
                    groupDigits(fxSupply / 1e18),
                    " in -> ",
                    groupDigits(amountOut / 1e18),
                    " out)"
                )
            );
        }

        console.log("");
        console.log(summary());
    }

    function checkGlobalOnlyLimit(
        string memory pair,
        string memory asset,
        bytes32 exchangeId,
        address token,
        int48 expectedLimitGlobal
    ) internal view {
        bytes32 id = limitId(exchangeId, token);
        (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags) =
            IBrokerTradingLimits(brokerProxy).tradingLimitsConfig(id);
        (,,,, int48 netflowGlobal) = IBrokerTradingLimits(brokerProxy).tradingLimitsState(id);

        string memory label = string.concat(asset, " on ", pair);
        require(flags == LG, string.concat("flags not LG-only for ", label));
        require(limitGlobal == expectedLimitGlobal, string.concat("unexpected limitGlobal for ", label));
        require(limit0 == 0 && timestep0 == 0, string.concat("L0 config not cleared for ", label));
        require(limit1 == 0 && timestep1 == 0, string.concat("L1 config not cleared for ", label));
        require(netflowGlobal == 0, string.concat("netflowGlobal not reset for ", label));
    }

    /// @dev Simulates the full contraction of the FX stable at the current oracle rate: mints the
    ///      current total supply to a prober (pranking the Broker, which has mint rights on the
    ///      stable) and swaps all of it back to USDm through the Broker. Reverts if the new limits
    ///      (or pool buckets) would block the snapshot supply from fully exiting. State is
    ///      snapshotted and reverted around the simulation so post-proposal state stays untouched.
    function checkSupplyCanExit(bytes32 exchangeId, address usdmToken, address fxToken)
        internal
        returns (uint256 fxSupply, uint256 amountOut)
    {
        uint256 snapshot = vm.snapshotState();

        fxSupply = IERC20Metadata(fxToken).totalSupply();
        address prober = makeAddr("mgp20-supply-prober");

        vm.prank(brokerProxy);
        IStableTokenV2(fxToken).mint(prober, fxSupply);

        vm.startPrank(prober);
        IERC20Metadata(fxToken).approve(brokerProxy, fxSupply);
        amountOut = IBroker(brokerProxy).swapIn(biPoolManagerProxy, exchangeId, fxToken, usdmToken, fxSupply, 0);
        vm.stopPrank();

        vm.revertToState(snapshot);
    }

    /// =========== Helpers ===========

    /// @dev Resolves a LimitUpdate to token addresses and the live exchangeId on the BiPoolManager,
    ///      counting how many live exchanges pair the two assets (either order). Exchange ids
    ///      cannot be recomputed from config because on-chain ids were hashed from since-renamed
    ///      token symbols. The caller requires exactly one match.
    function resolve(LimitUpdate memory update)
        internal
        view
        returns (address token0, address token1, bytes32 exchangeId, uint256 matches)
    {
        token0 = lookupProxyOrFail(update.asset0);
        token1 = lookupProxyOrFail(update.asset1);

        bytes32[] memory ids = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(ids[i]);
            bool assetsMatch =
                (pool.asset0 == token0 && pool.asset1 == token1) || (pool.asset0 == token1 && pool.asset1 == token0);
            if (assetsMatch) {
                exchangeId = ids[i];
                matches++;
            }
        }
    }

    function limitId(bytes32 exchangeId, address token) internal pure returns (bytes32) {
        return exchangeId ^ bytes32(uint256(uint160(token)));
    }

    function direction(int48 proposed, int48 current) internal pure returns (string memory) {
        if (proposed > current) return "increase";
        if (proposed < current) return "reduce";
        return "unchanged";
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

    /// @dev Formats an oracle rate (numerator/denominator) as a decimal with 4 fractional
    ///      digits, e.g. "0.7132". Enough precision for the smallest FX rates (COP, XOF).
    function formatRate(uint256 numerator, uint256 denominator) internal pure returns (string memory) {
        uint256 integerPart = numerator / denominator;
        uint256 fractionalPart = (numerator * 10_000) / denominator % 10_000;

        bytes memory frac = bytes(vm.toString(fractionalPart + 10_000)); // left-pad with the leading 1
        frac[0] = ".";
        return string.concat(groupDigits(integerPart), string(frac));
    }
}
