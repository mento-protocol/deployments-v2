// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";
import {IOpenLiquidityStrategy} from "mento-core/interfaces/IOpenLiquidityStrategy.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";
import {OracleHelper} from "../helpers/OracleHelper.sol";

/// @dev Exposes the auto-generated getter for LiquidityStrategy.poolConfigs so we can
/// read back and verify every parameter that addPool stored on-chain.
interface ILiquidityStrategyPoolConfigs {
    function poolConfigs(address pool)
        external
        view
        returns (
            bool isToken0Debt,
            uint32 lastRebalance,
            uint32 rebalanceCooldown,
            address protocolFeeRecipient,
            uint64 liquiditySourceIncentiveExpansion,
            uint64 protocolIncentiveExpansion,
            uint64 liquiditySourceIncentiveContraction,
            uint64 protocolIncentiveContraction
        );
}

/**
 * @title ConfigureOLSOnEuropFPMM
 * @notice Configures the (already deployed) OpenLiquidityStrategy on the existing
 *         EURm/EUROP FPMM. The pool was created by CreateFPMM with only a
 *         ReserveLiquidityStrategy; this script adds the OpenLiquidityStrategy
 *         alongside it, performing the exact same steps CreateFPMM does in
 *         _setupOpenLiquidityStrategy, plus an optional rebalanceIncentive update:
 *
 *           1. IFPMM.setRebalanceIncentive(REBALANCE_INCENTIVE) -- only sent if the pool's
 *              current value differs from the target. The FPMM requires a rebalancer to send
 *              in at least (1 - rebalanceIncentive) of fair value, while the OLS sends
 *              (1 - combined OLS incentives), so the pool's rebalanceIncentive must always
 *              cover the combined OLS incentives or every OLS rebalance reverts
 *              InsufficientAmountIn (enforced in the preflight checks). Sent by
 *              migrationOwner, which is the pool's feeSetter.
 *           2. IFPMM.setLiquidityStrategy(strategy, true)   -- enable the strategy on the pool
 *           3. IOpenLiquidityStrategy.addPool(params)       -- register the pool on the strategy
 *           4. Verify the configuration landed on-chain (incl. reading back every
 *              addPool parameter from the strategy's poolConfigs storage)
 *           5. Simulation-only rebalance smoke test (uses cheatcodes; nothing from
 *              step 5 is ever broadcast)
 *
 *         Steps 1-3 are guarded so re-running the script is a no-op for
 *         anything that already landed (addPool reverts LS_POOL_ALREADY_EXISTS
 *         if called twice).
 *
 * @dev The liquidity strategy parameters live in _olsPoolConfig() below, in the
 *      same format as the LiquidityStrategyPoolConfig blocks in MentoConfig_polygon.
 */
contract ConfigureOLSOnEuropFPMM is TrebScript, ProxyHelper, ConfigHelper, StdCheats {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;

    address constant SWAP_TEST_ACCOUNT = address(1337);

    // The single pool this script is allowed to touch.
    string constant DEBT_SYMBOL = "EURm";
    string constant COLLATERAL_SYMBOL = "EUROP";

    Senders.Sender owner;
    IFPMMFactory factory;

    /// =====================================================================
    /// USER-PROVIDED PARAMETERS
    /// Same format as the LiquidityStrategyPoolConfig blocks in
    /// script/config/mento/MentoConfig_polygon.sol. Edit before running.
    ///
    /// TODO: BEFORE DEPLOYMENT confirm the final value of REBALANCE_INCENTIVE
    /// and of EVERY field in _olsPoolConfig() below.
    /// =====================================================================

    /// @dev The pool's rebalanceIncentive (in bps) must cover the combined OLS
    /// incentives below, or every OLS rebalance reverts InsufficientAmountIn.
    /// 1 bps is the value the pool is currently configured with (i.e. no change);
    /// raise it here if the OLS incentives are ever raised (for reference, the
    /// USDm/EURm OLS pool uses 2 bps incentives with rebalanceIncentive = 3).
    uint256 constant REBALANCE_INCENTIVE = 1; // TODO: confirm final value

    function _olsPoolConfig() internal returns (IMentoConfig.LiquidityStrategyPoolConfig memory) {
        return IMentoConfig.LiquidityStrategyPoolConfig({
            liquidityStrategy: lookupProxyOrFail("OpenLiquidityStrategy"),
            debtToken: config.getAddress(DEBT_SYMBOL), // TODO: confirm final value
            cooldown: 300, // TODO: confirm final value
            protocolFeeRecipient: lookupOrFail("ProtocolFeeRecipient"), // TODO: confirm final value
            liquiditySourceIncentiveExpansion: 0, // 0% -- TODO: confirm final value
            protocolIncentiveExpansion: 0, // 0% -- TODO: confirm final value
            liquiditySourceIncentiveContraction: 0, // 0% -- TODO: confirm final value
            protocolIncentiveContraction: 0 // 0% -- TODO: confirm final value
        });
    }

    /// @custom:senders deployer, migrationOwner
    function run() public virtual broadcast {
        owner = sender("migrationOwner");
        factory = IFPMMFactory(lookupProxyOrFail("FPMMFactory"));

        OracleHelper.refreshOracleRatesIfFork(lookupProxyOrFail("SortedOracles"), config);

        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg = _olsPoolConfig();

        address collateralToken = config.getAddress(COLLATERAL_SYMBOL);
        address fpmmProxy = factory.getPool(lsCfg.debtToken, collateralToken);
        require(fpmmProxy != address(0), "EURm/EUROP FPMM not found -- run CreateFPMM first");

        _logPlan(fpmmProxy, lsCfg);
        _preflightChecks(fpmmProxy, lsCfg);
        _configureOpenLiquidityStrategy(fpmmProxy, lsCfg);
        _verifyConfiguration(fpmmProxy, lsCfg);
        _verifyOpenRebalance(fpmmProxy, lsCfg);

        console.log("\n=====================================================================");
        console.log("  Done: OpenLiquidityStrategy configured on the EURm/EUROP FPMM");
        console.log("=====================================================================");
    }

    /// =====================================================================
    /// Plan / parameter logging
    /// =====================================================================

    function _logPlan(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg) internal view {
        IFPMM fpmm = IFPMM(fpmmProxy);

        console.log("=====================================================================");
        console.log("  ConfigureOLSOnEuropFPMM");
        console.log("  Adds the OpenLiquidityStrategy to the existing EURm/EUROP FPMM");
        console.log("=====================================================================");

        console.log("\n----- Target pool ---------------------------------------------------");
        console.log("  > FPMM proxy:", fpmmProxy);
        console.log("  > token0: %s (%s)", tokenSymbol(fpmm.token0()), fpmm.token0());
        console.log("  > token1: %s (%s)", tokenSymbol(fpmm.token1()), fpmm.token1());
        (uint256 r0, uint256 r1,) = fpmm.getReserves();
        console.log("  > current reserve0 (%s):", tokenSymbol(fpmm.token0()), r0);
        console.log("  > current reserve1 (%s):", tokenSymbol(fpmm.token1()), r1);
        console.log("  > current rebalanceIncentive (bps):", fpmm.rebalanceIncentive());
        console.log("  > target rebalanceIncentive (bps):", REBALANCE_INCENTIVE);

        console.log("\n----- OpenLiquidityStrategy parameters (to be sent via addPool) -----");
        console.log("  > liquidityStrategy (OpenLiquidityStrategy proxy):", lsCfg.liquidityStrategy);
        console.log("  > debtToken: %s (%s)", tokenSymbol(lsCfg.debtToken), lsCfg.debtToken);
        console.log("  > cooldown (seconds between rebalances):", lsCfg.cooldown);
        console.log("  > protocolFeeRecipient:", lsCfg.protocolFeeRecipient);
        _logIncentive("liquiditySourceIncentiveExpansion", lsCfg.liquiditySourceIncentiveExpansion);
        _logIncentive("protocolIncentiveExpansion", lsCfg.protocolIncentiveExpansion);
        _logIncentive("liquiditySourceIncentiveContraction", lsCfg.liquiditySourceIncentiveContraction);
        _logIncentive("protocolIncentiveContraction", lsCfg.protocolIncentiveContraction);
    }

    /// @dev Incentives are 18-decimal fractions (1e18 = 100%, 1e14 = 1 bps).
    function _logIncentive(string memory name, uint64 value) internal pure {
        if (uint256(value) % 1e14 == 0) {
            console.log(string.concat("  > ", name, ":"), value, "| in bps:", uint256(value) / 1e14);
        } else {
            console.log(string.concat("  > ", name, ":"), value, "(not a whole bps; 1e14 = 1 bps)");
        }
    }

    /// =====================================================================
    /// Preflight checks (read-only, nothing sent yet)
    /// =====================================================================

    function _preflightChecks(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);
        address strategyAddy = lsCfg.liquidityStrategy;

        console.log("\n----- Preflight checks ----------------------------------------------");

        require(strategyAddy.code.length > 0, "Preflight: OpenLiquidityStrategy has no code");
        console.log("  > OpenLiquidityStrategy has code: OK");

        // Guard against accidentally pointing this script at a ReserveLiquidityStrategy:
        // an OLS does not expose reserve().
        require(
            !_isReserveLiquidityStrategy(strategyAddy),
            "Preflight: configured strategy exposes reserve() -- looks like a ReserveLiquidityStrategy, not an OLS"
        );
        console.log("  > Strategy is not a ReserveLiquidityStrategy: OK");

        require(
            lsCfg.debtToken == fpmm.token0() || lsCfg.debtToken == fpmm.token1(),
            "Preflight: debtToken is not one of the pool tokens"
        );
        console.log("  > debtToken %s is part of the pool: OK", tokenSymbol(lsCfg.debtToken));

        // The FPMM requires a rebalancer to send in at least (1 - rebalanceIncentive) of fair
        // value, while the OLS sends (1 - combined incentives). The target rebalanceIncentive
        // must therefore cover the combined OLS incentives, or rebalances always revert.
        uint256 requiredBps = _maxCombinedIncentiveBps(lsCfg);
        require(
            REBALANCE_INCENTIVE >= requiredBps,
            "Preflight: REBALANCE_INCENTIVE does not cover the combined OLS incentives"
        );
        console.log(
            "  > target rebalanceIncentive (%s bps) covers combined OLS incentives (%s bps): OK",
            REBALANCE_INCENTIVE,
            requiredBps
        );

        // setRebalanceIncentive is gated to the pool's feeSetter; we send it from migrationOwner.
        if (fpmm.rebalanceIncentive() != REBALANCE_INCENTIVE) {
            require(
                fpmm.feeSetter() == owner.account,
                "Preflight: migrationOwner is not the pool's feeSetter, cannot update rebalanceIncentive"
            );
            console.log("  > migrationOwner is the pool's feeSetter: OK");
        }

        // Informational: current strategy wiring on this pool.
        address rls = lookupProxy("ReserveLiquidityStrategy");
        if (rls != address(0)) {
            console.log(
                "  > (info) ReserveLiquidityStrategy (%s) enabled on this FPMM:", rls, fpmm.liquidityStrategy(rls)
            );
        }
        console.log("  > (info) OpenLiquidityStrategy already enabled on this FPMM:", fpmm.liquidityStrategy(strategyAddy));
        console.log(
            "  > (info) Pool already registered on OpenLiquidityStrategy:",
            ILiquidityStrategy(strategyAddy).isPoolRegistered(fpmmProxy)
        );
    }

    function _isReserveLiquidityStrategy(address strategyAddy) internal view returns (bool) {
        try IReserveLiquidityStrategy(strategyAddy).reserve() returns (IReserveV2) {
            return true;
        } catch {
            return false;
        }
    }

    /// =====================================================================
    /// Configuration (same steps as CreateFPMM._setupOpenLiquidityStrategy,
    /// guarded so a partial re-run doesn't re-send what already landed)
    /// =====================================================================

    function _configureOpenLiquidityStrategy(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg)
        internal
    {
        address strategyAddy = lsCfg.liquidityStrategy;

        console.log("\n----- Actions -------------------------------------------------------");

        // 1. Update the pool's rebalanceIncentive if it differs from the target
        if (IFPMM(fpmmProxy).rebalanceIncentive() == REBALANCE_INCENTIVE) {
            console.log("  [1/3] rebalanceIncentive already at target -- skipping setRebalanceIncentive");
        } else {
            console.log(
                "  [1/3] Calling FPMM.setRebalanceIncentive: %s bps -> %s bps ...",
                IFPMM(fpmmProxy).rebalanceIncentive(),
                REBALANCE_INCENTIVE
            );
            IFPMM(owner.harness(fpmmProxy)).setRebalanceIncentive(REBALANCE_INCENTIVE);
            console.log("        > rebalanceIncentive updated");
        }

        // 2. Enable the strategy on the FPMM
        if (IFPMM(fpmmProxy).liquidityStrategy(strategyAddy)) {
            console.log("  [2/3] OpenLiquidityStrategy already enabled on FPMM -- skipping setLiquidityStrategy");
        } else {
            console.log("  [2/3] Calling FPMM.setLiquidityStrategy(%s, true) ...", strategyAddy);
            IFPMM(owner.harness(fpmmProxy)).setLiquidityStrategy(strategyAddy, true);
            console.log("        > OpenLiquidityStrategy enabled on FPMM");
        }

        // 3. Register the FPMM as a pool on the strategy
        if (ILiquidityStrategy(strategyAddy).isPoolRegistered(fpmmProxy)) {
            console.log("  [3/3] Pool already registered on OpenLiquidityStrategy -- skipping addPool");
        } else {
            console.log("  [3/3] Calling OpenLiquidityStrategy.addPool(...) for pool %s ...", fpmmProxy);
            IOpenLiquidityStrategy(owner.harness(strategyAddy)).addPool(_buildAddPoolParams(fpmmProxy, lsCfg));
            console.log("        > Pool registered on OpenLiquidityStrategy");
        }
    }

    /// @dev The worse (higher) of the expansion-side and contraction-side combined
    /// incentives, in whole bps rounded up. Incentives compound multiplicatively:
    /// combined = 1 - (1 - protocolIncentive) * (1 - liquiditySourceIncentive).
    function _maxCombinedIncentiveBps(IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg)
        internal
        pure
        returns (uint256)
    {
        uint256 expansion = _combineIncentives(lsCfg.protocolIncentiveExpansion, lsCfg.liquiditySourceIncentiveExpansion);
        uint256 contraction =
            _combineIncentives(lsCfg.protocolIncentiveContraction, lsCfg.liquiditySourceIncentiveContraction);
        uint256 combined = expansion > contraction ? expansion : contraction;
        return (combined + 1e14 - 1) / 1e14; // ceil to whole bps (1 bps = 1e14)
    }

    function _combineIncentives(uint64 protocolIncentive, uint64 liquiditySourceIncentive)
        internal
        pure
        returns (uint256)
    {
        return 1e18 - ((1e18 - uint256(protocolIncentive)) * (1e18 - uint256(liquiditySourceIncentive))) / 1e18;
    }

    function _buildAddPoolParams(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg)
        internal
        pure
        returns (ILiquidityStrategy.AddPoolParams memory)
    {
        return ILiquidityStrategy.AddPoolParams({
            pool: fpmmProxy,
            debtToken: lsCfg.debtToken,
            cooldown: lsCfg.cooldown,
            protocolFeeRecipient: lsCfg.protocolFeeRecipient,
            liquiditySourceIncentiveExpansion: lsCfg.liquiditySourceIncentiveExpansion,
            protocolIncentiveExpansion: lsCfg.protocolIncentiveExpansion,
            liquiditySourceIncentiveContraction: lsCfg.liquiditySourceIncentiveContraction,
            protocolIncentiveContraction: lsCfg.protocolIncentiveContraction
        });
    }

    /// =====================================================================
    /// Verification
    /// =====================================================================

    function _verifyConfiguration(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg)
        internal
        view
    {
        address strategyAddy = lsCfg.liquidityStrategy;

        console.log("\n----- Verification --------------------------------------------------");

        // rebalanceIncentive is at the target value
        require(
            IFPMM(fpmmProxy).rebalanceIncentive() == REBALANCE_INCENTIVE, "Verify: rebalanceIncentive mismatch"
        );
        console.log("  > FPMM rebalanceIncentive is at target (%s bps): OK", REBALANCE_INCENTIVE);

        // Strategy is enabled on the FPMM
        require(
            IFPMM(fpmmProxy).liquidityStrategy(strategyAddy), "Verify: strategy not set as liquidity strategy on FPMM"
        );
        console.log("  > FPMM reports OpenLiquidityStrategy as enabled: OK");

        // Pool is registered on the strategy
        require(
            ILiquidityStrategy(strategyAddy).isPoolRegistered(fpmmProxy),
            "Verify: FPMM not registered as pool on strategy"
        );
        console.log("  > OpenLiquidityStrategy reports pool as registered: OK");

        // Read back the stored pool config and compare it field by field with
        // what we intended to configure.
        (
            bool isToken0Debt,
            uint32 lastRebalance,
            uint32 rebalanceCooldown,
            address protocolFeeRecipient,
            uint64 lsIncExpansion,
            uint64 protIncExpansion,
            uint64 lsIncContraction,
            uint64 protIncContraction
        ) = ILiquidityStrategyPoolConfigs(strategyAddy).poolConfigs(fpmmProxy);

        console.log("  > On-chain pool config stored on the strategy:");
        console.log("    > isToken0Debt:", isToken0Debt);
        console.log("    > lastRebalance:", lastRebalance);
        console.log("    > rebalanceCooldown:", rebalanceCooldown);
        console.log("    > protocolFeeRecipient:", protocolFeeRecipient);
        console.log("    > liquiditySourceIncentiveExpansion:", lsIncExpansion);
        console.log("    > protocolIncentiveExpansion:", protIncExpansion);
        console.log("    > liquiditySourceIncentiveContraction:", lsIncContraction);
        console.log("    > protocolIncentiveContraction:", protIncContraction);

        bool expectedIsToken0Debt = lsCfg.debtToken == IFPMM(fpmmProxy).token0();
        require(isToken0Debt == expectedIsToken0Debt, "Verify: isToken0Debt mismatch");
        require(rebalanceCooldown == lsCfg.cooldown, "Verify: cooldown mismatch");
        require(protocolFeeRecipient == lsCfg.protocolFeeRecipient, "Verify: protocolFeeRecipient mismatch");
        require(
            lsIncExpansion == lsCfg.liquiditySourceIncentiveExpansion,
            "Verify: liquiditySourceIncentiveExpansion mismatch"
        );
        require(protIncExpansion == lsCfg.protocolIncentiveExpansion, "Verify: protocolIncentiveExpansion mismatch");
        require(
            lsIncContraction == lsCfg.liquiditySourceIncentiveContraction,
            "Verify: liquiditySourceIncentiveContraction mismatch"
        );
        require(
            protIncContraction == lsCfg.protocolIncentiveContraction, "Verify: protocolIncentiveContraction mismatch"
        );
        console.log("  > All stored parameters match the configured values: OK");
    }

    /// =====================================================================
    /// Rebalance smoke test (simulation only)
    /// Verbatim CreateFPMM._verifyOpenRebalance: uses deal/prank cheatcodes,
    /// so it only runs in the fork simulation and is never broadcast.
    /// =====================================================================

    function _verifyOpenRebalance(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);

        // The live pool only holds dust reserves; the strategy's rebalance math
        // (and the FPMM's amount-in checks) degenerate on dust amounts. CreateFPMM
        // only ever ran this smoke test after providing ~10k units of liquidity in
        // the simulation, so do the same here.
        _provideLargerLiquidity(fpmmProxy);

        address sorted0 = fpmm.token0();
        address sorted1 = fpmm.token1();

        uint256 decimals0 = 10 ** IERC20Metadata(sorted0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(sorted1).decimals();

        // Fund the rebalancer with tokens (OpenLiquidityStrategy requires the caller to hold tokens)
        address rebalancer = SWAP_TEST_ACCOUNT;
        deal(sorted0, rebalancer, 100_000 * decimals0);
        deal(sorted1, rebalancer, 100_000 * decimals1);

        // Approve the strategy to spend the rebalancer's tokens
        vm.prank(rebalancer);
        IERC20(sorted0).approve(lsCfg.liquidityStrategy, type(uint256).max);
        vm.prank(rebalancer);
        IERC20(sorted1).approve(lsCfg.liquidityStrategy, type(uint256).max);

        // 1. Do a large one-sided swap to push the pool out of balance
        _doLargeSwap(fpmmProxy, fpmm);

        // 2. Log rebalancing state before rebalance
        uint256 priceDifference;
        {
            (uint256 oPN, uint256 oPD, uint256 rPN, uint256 rPD, bool above,, uint256 pd) = fpmm.getRebalancingState();
            priceDifference = pd;
            console.log("  > oraclePrice:", oPN, "/", oPD);
            console.log("  > reservePrice:", rPN, "/", rPD);
            console.log("  > reservePriceAboveOracle:", above);
            console.log("  > priceDifference (bps):", pd);
        }

        // 3. Trigger rebalance from the funded rebalancer account
        {
            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
            vm.prank(rebalancer);
            ILiquidityStrategy(lsCfg.liquidityStrategy).rebalance(fpmmProxy);
            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();
            console.log("  > reserve0 before:", r0Before, "-> after:", r0After);
            console.log("  > reserve1 before:", r1Before, "-> after:", r1After);
        }

        // 4. Verify price difference improved
        (,,,,,, uint256 newPriceDifference) = fpmm.getRebalancingState();
        console.log("  > newPriceDifference (bps):", newPriceDifference);
        require(newPriceDifference < priceDifference, "Verify: rebalance did not improve price difference");
        console.log("  > Rebalance through the OpenLiquidityStrategy works: OK");
    }

    /// @dev Same as CreateFPMM._provideLargerLiquidity, except the rate feed and
    /// inversion flag are read from the live pool instead of the FPMMConfig.
    function _provideLargerLiquidity(address fpmmProxy) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);
        address token0 = fpmm.token0();
        address token1 = fpmm.token1();

        IOracleAdapter oracle = fpmm.oracleAdapter();
        (uint256 rateNumerator, uint256 rateDenominator) = oracle.getFXRateIfValid(fpmm.referenceRateFeedID());
        if (fpmm.invertRateFeed()) {
            (rateNumerator, rateDenominator) = (rateDenominator, rateNumerator);
        }

        uint256 decimals0 = 10 ** IERC20Metadata(token0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(token1).decimals();

        uint256 amount0 = 10_000 * decimals0;
        uint256 amount1 = (amount0 * rateNumerator * decimals1) / (rateDenominator * decimals0);

        // Mint tokens for liquidity
        deal(token0, SWAP_TEST_ACCOUNT, amount0);
        deal(token1, SWAP_TEST_ACCOUNT, amount1);

        // Transfer and mint LP
        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(token0).transfer(fpmmProxy, amount0);
        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(token1).transfer(fpmmProxy, amount1);
        vm.prank(SWAP_TEST_ACCOUNT);
        uint256 liquidity = fpmm.mint(SWAP_TEST_ACCOUNT);

        console.log("\n----- Provided larger liquidity (simulation only) -------------------");
        console.log("  > amount0 (%s):", tokenSymbol(token0), amount0);
        console.log("  > amount1 (%s):", tokenSymbol(token1), amount1);
        console.log("  > liquidity:", liquidity);
    }

    function _doLargeSwap(address fpmmProxy, IFPMM fpmm) internal {
        address token0 = fpmm.token0();
        (uint256 reserve0,,) = fpmm.getReserves();
        uint256 largeSwapAmount = reserve0 / 4;

        deal(token0, SWAP_TEST_ACCOUNT, largeSwapAmount);
        uint256 amountOut = fpmm.getAmountOut(largeSwapAmount, token0);

        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(token0).transfer(fpmmProxy, largeSwapAmount);
        vm.prank(SWAP_TEST_ACCOUNT);
        fpmm.swap(0, amountOut, SWAP_TEST_ACCOUNT, "");

        console.log("\n----- Rebalance smoke test (simulation only) ------------------------");
        console.log("  > large swap to imbalance pool (token0 -> token1):");
        console.log("    > swapIn:", largeSwapAmount);
        console.log("    > swapOut:", amountOut);
    }

    function tokenSymbol(address token) internal view returns (string memory) {
        return IERC20Metadata(token).symbol();
    }
}
