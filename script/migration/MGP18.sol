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

/// @dev Minimal interface for the Broker's auto-generated public mapping getter.
interface IBrokerTradingLimits {
    function tradingLimitsConfig(bytes32 limitId)
        external
        view
        returns (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags);
}

/**
 * @title MGP18
 * @notice Lowers the trading limits on the exchanges that remain in Mento v2.
 *         The FX stables staying on the v2 model (not migrated to v3/CDP) should not be able to
 *         grow their supply significantly, but the existing supply must always be able to fully
 *         contract back into collateral. So for each remaining exchange, the existing L0/L1/LG
 *         trading-limit configs are replaced with a global-only (LG) limit of:
 *           - FX asset:  the FX token's current total supply, and
 *           - USDm:      the USD equivalent of that supply at the current oracle rate.
 *         Each limit is first reset (configured with no flags, clearing the accumulated
 *         netflowGlobal) and then set to the new global-only value, so the new limits apply
 *         from a clean slate rather than on top of historical netflow.
 */
contract MGP18 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    uint8 internal constant LG = 4;

    /// @dev Buffer applied to both limits (1.05x) to absorb supply drift between proposal
    ///      creation and execution; see getProposedLimits.
    uint256 internal constant LIMIT_BUFFER_PCT = 105;

    /// @param asset0 Registry name of the exchange's first asset (USDm).
    /// @param asset1 Registry name of the exchange's second asset (the FX stable).
    /// @param limitGlobal0 Proposed global limit for asset0, computed on-chain in applyLimits.
    /// @param limitGlobal1 Proposed global limit for asset1, computed on-chain in applyLimits.
    struct LimitUpdate {
        string asset0;
        string asset1;
        int48 limitGlobal0;
        int48 limitGlobal1;
    }

    address internal brokerProxy;
    address internal biPoolManagerProxy;
    LimitUpdate[] internal updates;

    function setUp() public {
        brokerProxy = lookupProxyOrFail("Broker", ProxyType.CELO);
        biPoolManagerProxy = lookupProxyOrFail("BiPoolManager", ProxyType.CELO);

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
        ozGovSender.setTitle("MGP-18: Lower trading limits on remaining Mento v2 exchanges");
        ozGovSender.setProposalDescription("./mgps/mgp18.md");

        preChecks();

        applyLimits(govSender);

        postChecks();
    }

    function applyLimits(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Applying supply-based global-only trading limits ==");

        for (uint256 i = 0; i < updates.length; i++) {
            LimitUpdate storage update = updates[i];
            (address token0, address token1, bytes32 exchangeId,) = resolve(update);

            (uint256 rateNumerator, uint256 rateDenominator) = (0, 0);
            (update.limitGlobal0, update.limitGlobal1, rateNumerator, rateDenominator) =
                getProposedLimits(exchangeId, token0, token1);

            console.log(string.concat("Exchange (", update.asset0, "/", update.asset1, ")"));
            console.log(
                string.concat(
                    "   current ",
                    update.asset1,
                    " supply: ",
                    groupDigits(IERC20Metadata(token1).totalSupply() / 1e18)
                )
            );

            console.log(
                string.concat(
                    "   ...resetting netflow and setting ",
                    update.asset1,
                    " limit to global-only ",
                    groupDigits(uint256(int256(update.limitGlobal1)))
                )
            );
            resetAndSetGlobalLimit(govSender, exchangeId, token1, update.limitGlobal1);

            console.log(
                string.concat(
                    "   ...resetting netflow and setting ",
                    update.asset0,
                    " limit to global-only ",
                    groupDigits(uint256(int256(update.limitGlobal0))),
                    " (@ ",
                    formatRate(rateNumerator, rateDenominator),
                    " ",
                    update.asset1,
                    "/USD)"
                )
            );
            resetAndSetGlobalLimit(govSender, exchangeId, token0, update.limitGlobal0);
        }
    }

    /// @notice Computes the proposed global limits for an exchange:
    ///         the FX token's current total supply (whole tokens, rounded up) and its USD
    ///         equivalent at the current oracle rate, both scaled by LIMIT_BUFFER. Trading
    ///         limits are denominated in whole tokens: the Broker divides amounts by
    ///         10^decimals before applying them.
    /// @dev The oracle rate feeds for the FX exchanges ({CUR}USD) report USD per FX unit —
    ///      the same direction the BiPoolManager uses to derive the FX bucket from the USDm
    ///      bucket in getUpdatedBuckets.
    function getProposedLimits(bytes32 exchangeId, address usdmToken, address fxToken)
        internal
        view
        returns (int48 usdmLimit, int48 fxLimit, uint256 rateNumerator, uint256 rateDenominator)
    {
        // The limits are frozen into the proposal calldata now, but the supply keeps moving
        // until the proposal executes after the voting/timelock window. If the supply grows in
        // between, a 1x limit would leave the excess unable to exit back to USDm. The 5%
        // buffer absorbs that drift, at the cost of allowing supply to grow by up to the same
        // margin.
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

        ITradingLimits.Config memory config;
        config.limitGlobal = limitGlobal;
        config.flags = LG;
        IBroker(govSender.harness(brokerProxy)).configureTradingLimit(exchangeId, token, config);
    }

    /// =========== Proposal checks ===========

    /// @dev Before: every configured pair must have a live exchange and a trading limit
    ///      configured on both assets.
    function preChecks() internal view {
        console.log("== Pre-checks ==");

        for (uint256 i = 0; i < updates.length; i++) {
            LimitUpdate memory update = updates[i];
            string memory pair = string.concat(update.asset0, "/", update.asset1);
            (address token0, address token1, bytes32 exchangeId, bool live) = resolve(update);

            require(live, string.concat("no live exchange for ", pair));

            (,,,,, uint8 flags0) = IBrokerTradingLimits(brokerProxy).tradingLimitsConfig(limitId(exchangeId, token0));
            require(flags0 != 0, string.concat("no trading limit configured for ", update.asset0, " on ", pair));

            (,,,,, uint8 flags1) = IBrokerTradingLimits(brokerProxy).tradingLimitsConfig(limitId(exchangeId, token1));
            require(flags1 != 0, string.concat("no trading limit configured for ", update.asset1, " on ", pair));

            console.log(unicode" > 🟢 %s: exchange live, limits configured on both assets", pair);
        }
    }

    /// @dev After: every configured pair must have a global-only limit on both assets (no L0,
    ///      no L1, only LG with the expected value), and the FX token's entire supply must be
    ///      swappable back to USDm under the new limits.
    function postChecks() internal {
        console.log("");
        console.log("== Post-checks ==");

        for (uint256 i = 0; i < updates.length; i++) {
            LimitUpdate memory update = updates[i];
            string memory pair = string.concat(update.asset0, "/", update.asset1);
            (address token0, address token1, bytes32 exchangeId,) = resolve(update);

            checkGlobalOnlyLimit(pair, update.asset0, exchangeId, token0, update.limitGlobal0);
            checkGlobalOnlyLimit(pair, update.asset1, exchangeId, token1, update.limitGlobal1);
            console.log(unicode" > 🟢 %s: global-only limits set on both assets", pair);

            checkSupplyCanExit(pair, exchangeId, token0, token1);
        }
    }

    function checkGlobalOnlyLimit(
        string memory pair,
        string memory asset,
        bytes32 exchangeId,
        address token,
        int48 expectedLimitGlobal
    ) internal view {
        (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags) =
            IBrokerTradingLimits(brokerProxy).tradingLimitsConfig(limitId(exchangeId, token));

        string memory label = string.concat(asset, " on ", pair);
        require(flags == LG, string.concat("flags not LG-only for ", label));
        require(limitGlobal == expectedLimitGlobal, string.concat("unexpected limitGlobal for ", label));
        require(limit0 == 0 && timestep0 == 0, string.concat("L0 config not cleared for ", label));
        require(limit1 == 0 && timestep1 == 0, string.concat("L1 config not cleared for ", label));
    }

    /// @dev Simulates the full contraction of the FX stable: mints the current total supply to a
    ///      prober (pranking the Broker, which has mint rights on the stable) and swaps all of it
    ///      back to USDm through the Broker. Reverts if the new limits (or pool buckets) would
    ///      block the supply from fully exiting. State is snapshotted and reverted around the
    ///      simulation so post-proposal state stays untouched.
    function checkSupplyCanExit(string memory pair, bytes32 exchangeId, address usdmToken, address fxToken) internal {
        uint256 snapshot = vm.snapshotState();

        uint256 fxSupply = IERC20Metadata(fxToken).totalSupply();
        address prober = makeAddr("mgp18-supply-prober");

        vm.prank(brokerProxy);
        IStableTokenV2(fxToken).mint(prober, fxSupply);

        vm.startPrank(prober);
        IERC20Metadata(fxToken).approve(brokerProxy, fxSupply);
        uint256 amountOut =
            IBroker(brokerProxy).swapIn(biPoolManagerProxy, exchangeId, fxToken, usdmToken, fxSupply, 0);
        vm.stopPrank();

        console.log(
            unicode" > 🟢 %s: full supply can exit to USDm (%s in -> %s out)",
            pair,
            groupDigits(fxSupply / 1e18),
            groupDigits(amountOut / 1e18)
        );

        vm.revertToState(snapshot);
    }

    /// =========== Helpers ===========

    /// @dev Resolves a LimitUpdate to token addresses and the live exchangeId on the BiPoolManager.
    ///      Exchanges are matched by assets (either order); exchangeIds cannot be recomputed from
    ///      config because on-chain ids were hashed from since-renamed token symbols.
    function resolve(LimitUpdate memory update)
        internal
        view
        returns (address token0, address token1, bytes32 exchangeId, bool live)
    {
        token0 = lookupProxyOrFail(update.asset0);
        token1 = lookupProxyOrFail(update.asset1);

        bytes32[] memory ids = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(ids[i]);
            bool assetsMatch =
                (pool.asset0 == token0 && pool.asset1 == token1) || (pool.asset0 == token1 && pool.asset1 == token0);
            if (assetsMatch) {
                return (token0, token1, ids[i], true);
            }
        }
    }

    function limitId(bytes32 exchangeId, address token) internal pure returns (bytes32) {
        return exchangeId ^ bytes32(uint256(uint160(token)));
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
