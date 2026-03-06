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
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";
import {OracleHelper} from "../helpers/OracleHelper.sol";

contract CreateFPMM is TrebScript, ProxyHelper, ConfigHelper, StdCheats {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;

    address constant SWAP_TEST_ACCOUNT = address(1337);

    IFPMMFactory factoryHarness;
    IFPMMFactory factory;
    Senders.Sender owner;

    /// @custom:senders deployer, migrationOwner
    function run() public virtual broadcast {
        owner = sender("migrationOwner");
        address factoryAddy = lookupProxyOrFail("FPMMFactory");
        factoryHarness = IFPMMFactory(owner.harness(factoryAddy));
        factory = IFPMMFactory(factoryAddy);

        OracleHelper.refreshOracleRatesIfFork(lookupProxyOrFail("SortedOracles"), config);

        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            _deployFPMM(fpmmConfigs[i]);
        }
    }

    function _deployFPMM(IMentoConfig.FPMMConfig memory cfg) internal {
        address fpmmProxy = factory.getPool(cfg.token0, cfg.token1);

        if (fpmmProxy != address(0)) {
            string memory token0Symbol = IERC20Metadata(cfg.token0).symbol();
            string memory token1Symbol = IERC20Metadata(cfg.token1).symbol();
            console.log("  > fpmm already exists for (%s, %s)", token0Symbol, token1Symbol);
            return;
        }

        fpmmProxy = _createFPMM(cfg);
        _configureTradingLimits(fpmmProxy, cfg);
        _verifySwap(fpmmProxy, cfg);

        bool hasReserveLiqStrategy = cfg.rlsConfig.reserveLiquidityStrategy != address(0);
        if (hasReserveLiqStrategy) {
            _setupReserveLiquidityStrategy(fpmmProxy, cfg.token0, cfg.token1, cfg.rlsConfig);
        } else {
            console.log("  > Not setting up ReserveLiquidityStrategy for FPMM");
        }
    }

    function _createFPMM(IMentoConfig.FPMMConfig memory cfg) internal returns (address) {
        address proxy = factoryHarness.deployFPMM(
            cfg.fpmmImplementation,
            cfg.oracleAdapter,
            cfg.proxyAdmin,
            owner.account,
            cfg.token0,
            cfg.token1,
            cfg.referenceRateFeedID,
            cfg.invertRateFeed,
            cfg.params
        );

        IFPMM fpmm = IFPMM(proxy);

        string memory token0Symbol = IERC20Metadata(fpmm.token0()).symbol();
        string memory token1Symbol = IERC20Metadata(fpmm.token1()).symbol();

        console.log("\n===== Created FPMM pool =====");
        console.log("  > token0: %s (%s)", token0Symbol, fpmm.token0());
        console.log("  > token1: %s (%s)", token1Symbol, fpmm.token1());
        console.log("  > referenceRateFeedID:", fpmm.referenceRateFeedID());
        console.log("  > invertRateFeed:", fpmm.invertRateFeed());

        _mintInitialLiquidity(proxy, cfg);
        _verifyFPMM(proxy, cfg);
        _verifyInitialLiquidity(proxy);

        return proxy;
    }

    function _configureTradingLimits(address fpmmProxy, IMentoConfig.FPMMConfig memory cfg) internal {
        IMentoConfig.FPMMTradingLimitsConfig memory limits = cfg.tradingLimits;

        bool hasToken0Limits = limits.token0Limit0 > 0 || limits.token0Limit1 > 0;
        bool hasToken1Limits = limits.token1Limit0 > 0 || limits.token1Limit1 > 0;

        if (hasToken0Limits) {
            IFPMM(owner.harness(fpmmProxy)).configureTradingLimit(cfg.token0, limits.token0Limit0, limits.token0Limit1);
            console.log("  > Configured trading limits for token0 (%s)", IERC20Metadata(cfg.token0).symbol());
            console.log("    > limit0:", limits.token0Limit0);
            console.log("    > limit1:", limits.token0Limit1);
        }

        if (hasToken1Limits) {
            IFPMM(owner.harness(fpmmProxy)).configureTradingLimit(cfg.token1, limits.token1Limit0, limits.token1Limit1);
            console.log("  > Configured trading limits for token1 (%s)", IERC20Metadata(cfg.token1).symbol());
            console.log("    > limit0:", limits.token1Limit0);
            console.log("    > limit1:", limits.token1Limit1);
        }

        if (!hasToken0Limits && !hasToken1Limits) {
            console.log("  > No trading limits configured for this FPMM");
        }

        console.log("\n");
    }

    function _setupReserveLiquidityStrategy(
        address fpmmProxy,
        address token0,
        address token1,
        IMentoConfig.ReserveLiquidityStrategyPoolConfig memory rls
    ) internal {
        address rlsAddy = rls.reserveLiquidityStrategy;
        address collateralToken = rls.debtToken == token0 ? token1 : token0;

        // 1. Register assets and RLS spender on ReserveV2 if not yet registered
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(rlsAddy).reserve();
        console.log("  Registering assets and RLS spender on ReserveV2");
        _registerReserveAssets(reserveV2, rls.debtToken, collateralToken, rlsAddy);

        // 2. Set RLS as liquidity strategy on the FPMM
        IFPMM(owner.harness(fpmmProxy)).setLiquidityStrategy(rlsAddy, true);
        console.log("  > Set liquidity strategy on FPMM:", rlsAddy);

        // 3. Configure the FPMM as a pool on the RLS
        IReserveLiquidityStrategy(owner.harness(rlsAddy))
            .addPool(
                ILiquidityStrategy.AddPoolParams({
                    pool: fpmmProxy,
                    debtToken: rls.debtToken,
                    cooldown: rls.cooldown,
                    protocolFeeRecipient: rls.protocolFeeRecipient,
                    liquiditySourceIncentiveExpansion: rls.liquiditySourceIncentiveExpansion,
                    protocolIncentiveExpansion: rls.protocolIncentiveExpansion,
                    liquiditySourceIncentiveContraction: rls.liquiditySourceIncentiveContraction,
                    protocolIncentiveContraction: rls.protocolIncentiveContraction
                })
            );
        console.log("  > Added pool to ReserveLiquidityStrategy");

        // 4. Grant minting and burning rights to the strategy on the debt token
        IStableTokenV3 debtToken = IStableTokenV3(rls.debtToken);
        if (!debtToken.isMinter(rlsAddy)) {
            IStableTokenV3(owner.harness(rls.debtToken)).setMinter(rlsAddy, true);
            console.log("  > Granted minter to strategy on:", tokenSymbol(rls.debtToken));
        }
        if (!debtToken.isBurner(rlsAddy)) {
            IStableTokenV3(owner.harness(rls.debtToken)).setBurner(rlsAddy, true);
            console.log("  > Granted burner to strategy on:", tokenSymbol(rls.debtToken));
        }
        console.log("\n");
        _verifyReserveLiquidityStrategy(fpmmProxy, token0, token1, rls);

        // Now try to trigger a rebalance through the configured RLS
        _verifyRebalance(fpmmProxy, rls);
    }

    function _registerReserveAssets(IReserveV2 reserveV2, address debtToken, address collateralToken, address rlsAddy)
        internal
    {
        address reserveAddy = address(reserveV2);

        if (!reserveV2.isStableAsset(debtToken)) {
            IReserveV2(owner.harness(reserveAddy)).registerStableAsset(debtToken);
            console.log("  > Registered stable asset on ReserveV2:", tokenSymbol(debtToken));
        }

        if (!reserveV2.isCollateralAsset(collateralToken)) {
            IReserveV2(owner.harness(reserveAddy)).registerCollateralAsset(collateralToken);
            console.log("  > Registered collateral asset on ReserveV2:", tokenSymbol(collateralToken));
        }

        if (!reserveV2.isLiquidityStrategySpender(rlsAddy)) {
            IReserveV2(owner.harness(reserveAddy)).registerLiquidityStrategySpender(rlsAddy);
            console.log("  > Registered RLS as spender on ReserveV2:", rlsAddy);
        }
    }

    function _mintInitialLiquidity(address fpmmProxy, IMentoConfig.FPMMConfig memory cfg) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);
        address token0 = fpmm.token0();
        address token1 = fpmm.token1();

        // Get the oracle rate (token0/token1 after invertRateFeed)
        IOracleAdapter oracle = fpmm.oracleAdapter();
        (uint256 rateNumerator, uint256 rateDenominator) = oracle.getFXRateIfValid(cfg.referenceRateFeedID);
        if (cfg.invertRateFeed) {
            (rateNumerator, rateDenominator) = (rateDenominator, rateNumerator);
        }

        uint256 decimals0 = 10 ** IERC20Metadata(token0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(token1).decimals();

        // 1 unit of token1 (collateral)
        uint256 amount1 = decimals1;
        // Convert to value-equivalent amount of token0 using oracle rate
        // rate = token0_price / token1_price, so amount0 = amount1 * rateDenominator * decimals0 / (rateNumerator * decimals1)
        uint256 amount0 = (amount1 * rateDenominator * decimals0) / (rateNumerator * decimals1);

        require(
            IERC20(token0).balanceOf(owner.account) >= amount0,
            "owner has insufficient token0 balance for initial liquidity"
        );
        require(
            IERC20(token1).balanceOf(owner.account) >= amount1,
            "owner has insufficient token1 balance for initial liquidity"
        );

        // Transfer tokens to the FPMM and mint
        IERC20(owner.harness(token0)).transfer(fpmmProxy, amount0);
        IERC20(owner.harness(token1)).transfer(fpmmProxy, amount1);
        uint256 liquidity = IFPMM(owner.harness(fpmmProxy)).mint(owner.account);

        console.log("  > minted initial liquidity");
        console.log("  > amount0:", amount0);
        console.log("  > amount1:", amount1);
        console.log("  > liquidity:", liquidity);
        console.log("\n");
    }

    // ========== Verification ==========

    function _verifyFPMM(address proxy, IMentoConfig.FPMMConfig memory cfg) internal view {
        require(factory.isPool(proxy), "Verify: factory does not report pool as deployed");

        IFPMM fpmm = IFPMM(proxy);
        require(fpmm.token0() == cfg.token0 && fpmm.token1() == cfg.token1, "Verify: FPMM token addresses mismatch");

        require(fpmm.referenceRateFeedID() == cfg.referenceRateFeedID, "Verify: FPMM referenceRateFeedID mismatch");
        require(fpmm.invertRateFeed() == cfg.invertRateFeed, "Verify: FPMM invertRateFeed mismatch");
        require(address(fpmm.oracleAdapter()) == cfg.oracleAdapter, "Verify: FPMM oracleAdapter mismatch");
        require(getProxyAdmin(proxy) == cfg.proxyAdmin, "Verify: FPMM proxyAdmin mismatch");

        _verifyFPMMParams(fpmm, cfg.params);
    }

    function _verifyFPMMParams(IFPMM fpmm, IFPMM.FPMMParams memory params) internal view {
        require(fpmm.lpFee() == params.lpFee, "Verify: FPMM lpFee mismatch");
        require(fpmm.protocolFee() == params.protocolFee, "Verify: FPMM protocolFee mismatch");
        require(
            fpmm.protocolFeeRecipient() == params.protocolFeeRecipient, "Verify: FPMM protocolFeeRecipient mismatch"
        );
        require(fpmm.feeSetter() == params.feeSetter, "Verify: FPMM feeSetter mismatch");
        require(fpmm.rebalanceIncentive() == params.rebalanceIncentive, "Verify: FPMM rebalanceIncentive mismatch");
        require(
            fpmm.rebalanceThresholdAbove() == params.rebalanceThresholdAbove,
            "Verify: FPMM rebalanceThresholdAbove mismatch"
        );
        require(
            fpmm.rebalanceThresholdBelow() == params.rebalanceThresholdBelow,
            "Verify: FPMM rebalanceThresholdBelow mismatch"
        );
    }

    function _verifyReserveLiquidityStrategy(
        address fpmmProxy,
        address token0,
        address token1,
        IMentoConfig.ReserveLiquidityStrategyPoolConfig memory rls
    ) internal view {
        address rlsAddy = rls.reserveLiquidityStrategy;
        address collateralToken = rls.debtToken == token0 ? token1 : token0;

        // Verify RLS is set as liquidity strategy on the FPMM
        require(IFPMM(fpmmProxy).liquidityStrategy(rlsAddy), "Verify: RLS not set as liquidity strategy on FPMM");

        // Verify pool is registered on the RLS
        require(ILiquidityStrategy(rlsAddy).isPoolRegistered(fpmmProxy), "Verify: FPMM not registered as pool on RLS");

        // Verify ReserveV2 asset registration
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(rlsAddy).reserve();
        require(reserveV2.isStableAsset(rls.debtToken), "Verify: debtToken not registered as stable asset on ReserveV2");
        require(
            reserveV2.isCollateralAsset(collateralToken),
            "Verify: collateralToken not registered as collateral asset on ReserveV2"
        );

        // Verify RLS is registered as spender on ReserveV2
        require(reserveV2.isLiquidityStrategySpender(rlsAddy), "Verify: RLS not registered as spender on ReserveV2");

        // Verify minter and burner rights
        IStableTokenV3 debtToken = IStableTokenV3(rls.debtToken);
        require(debtToken.isMinter(rlsAddy), "Verify: RLS not set as minter on debtToken");
        require(debtToken.isBurner(rlsAddy), "Verify: RLS not set as burner on debtToken");
    }

    function _verifyInitialLiquidity(address fpmmProxy) internal view {
        IFPMM fpmm = IFPMM(fpmmProxy);

        // Verify reserves are non-zero
        (uint256 r0, uint256 r1,) = fpmm.getReserves();
        require(r0 > 0, "Verify: FPMM reserve0 is zero after mint");
        require(r1 > 0, "Verify: FPMM reserve1 is zero after mint");

        // Verify LP total supply is non-zero and owner received LP tokens
        IERC20 lpToken = IERC20(fpmmProxy);
        require(lpToken.totalSupply() > 0, "Verify: FPMM totalSupply is zero after mint");
        require(lpToken.balanceOf(owner.account) > 0, "Verify: owner received no LP tokens");
    }

    // ======= Test helpers =======

    function _verifySwap(address fpmmProxy, IMentoConfig.FPMMConfig memory c) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);

        // Provide larger liquidity so we can swap meaningfully
        _provideLargerLiquidity(fpmmProxy, c);

        // Swap 100 units of token0 -> token1
        uint256 decimals0 = 10 ** IERC20Metadata(c.token0).decimals();
        uint256 swapAmountIn = 100 * decimals0;

        // Mint token0 to this contract for the swap
        _mintTokenForSwap(c.token0, SWAP_TEST_ACCOUNT, swapAmountIn);

        uint256 amountOut = fpmm.getAmountOut(swapAmountIn, c.token0);
        require(amountOut > 0, "Verify: swap amountOut is zero");

        // Transfer token0 to the FPMM and execute swap
        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(c.token0).transfer(fpmmProxy, swapAmountIn);
        uint256 balanceBefore = IERC20(c.token1).balanceOf(SWAP_TEST_ACCOUNT);
        vm.prank(SWAP_TEST_ACCOUNT);
        fpmm.swap(0, amountOut, SWAP_TEST_ACCOUNT, "");
        uint256 balanceAfter = IERC20(c.token1).balanceOf(SWAP_TEST_ACCOUNT);

        console.log("  ===== Swap Verification =====");
        console.log("  > swapIn (token0):", swapAmountIn);
        console.log("  > swapOut (token1):", amountOut);
        console.log("  > token1 received:", balanceAfter - balanceBefore);
    }

    function _mintTokenForSwap(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }

    function _verifyRebalance(address fpmmProxy, IMentoConfig.ReserveLiquidityStrategyPoolConfig memory rls) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);

        address sorted0 = fpmm.token0();
        address sorted1 = fpmm.token1();

        uint256 decimals0 = 10 ** IERC20Metadata(sorted0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(sorted1).decimals();
        address reserve = lookupProxyOrFail("ReserveV2");

        deal(sorted0, reserve, 100000 * decimals0);
        deal(sorted1, reserve, 100000 * decimals1);

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

        // 3. Trigger rebalance through the ReserveLiquidityStrategy
        {
            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
            ILiquidityStrategy(rls.reserveLiquidityStrategy).rebalance(fpmmProxy);
            (uint256 r0After, uint256 r1After,) = fpmm.getReserves();
            console.log("  > reserve0 before:", r0Before, "-> after:", r0After);
            console.log("  > reserve1 before:", r1Before, "-> after:", r1After);
        }

        // 4. Verify price difference improved
        (,,,,,, uint256 newPriceDifference) = fpmm.getRebalancingState();
        console.log("  > newPriceDifference (bps):", newPriceDifference);
        require(newPriceDifference < priceDifference, "Verify: rebalance did not improve price difference");
    }

    function _doLargeSwap(address fpmmProxy, IFPMM fpmm) internal {
        address token0 = fpmm.token0();
        uint256 largeSwapAmount = 5_000 * (10 ** IERC20Metadata(token0).decimals());

        _mintTokenForSwap(token0, SWAP_TEST_ACCOUNT, largeSwapAmount);
        uint256 amountOut = fpmm.getAmountOut(largeSwapAmount, token0);

        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(token0).transfer(fpmmProxy, largeSwapAmount);
        vm.prank(SWAP_TEST_ACCOUNT);
        fpmm.swap(0, amountOut, SWAP_TEST_ACCOUNT, "");

        console.log("\n  ===== Rebalance Verification =====");
        console.log("  > large swap to imbalance pool (token0 -> token1):");
        console.log("    > swapIn:", largeSwapAmount);
        console.log("    > swapOut:", amountOut);
    }

    function _provideLargerLiquidity(address fpmmProxy, IMentoConfig.FPMMConfig memory c) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);
        address token0 = c.token0;
        address token1 = c.token1;

        IOracleAdapter oracle = fpmm.oracleAdapter();
        (uint256 rateNumerator, uint256 rateDenominator) = oracle.getFXRateIfValid(c.referenceRateFeedID);
        if (c.invertRateFeed) {
            (rateNumerator, rateDenominator) = (rateDenominator, rateNumerator);
        }

        uint256 decimals0 = 10 ** IERC20Metadata(token0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(token1).decimals();

        // Provide 10_000 units of token1 worth of liquidity
        uint256 amount1 = 10_000 * decimals1;
        uint256 amount0 = (amount1 * rateDenominator * decimals0) / (rateNumerator * decimals1);

        // Mint tokens for liquidity
        _mintTokenForSwap(c.token0, SWAP_TEST_ACCOUNT, amount0);
        _mintTokenForSwap(c.token1, SWAP_TEST_ACCOUNT, amount1);

        // Transfer and mint LP
        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(c.token0).transfer(fpmmProxy, amount0);
        vm.prank(SWAP_TEST_ACCOUNT);
        IERC20(c.token1).transfer(fpmmProxy, amount1);
        vm.prank(SWAP_TEST_ACCOUNT);
        uint256 liquidity = fpmm.mint(SWAP_TEST_ACCOUNT);

        console.log("  ===== Provided Larger Liquidity =====");
        console.log("  > amount0:", amount0);
        console.log("  > amount1:", amount1);
        console.log("  > liquidity:", liquidity);
    }

    function tokenSymbol(address token) internal view returns (string memory) {
        return IERC20Metadata(token).symbol();
    }
}
