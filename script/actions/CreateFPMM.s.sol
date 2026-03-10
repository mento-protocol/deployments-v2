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

        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg = cfg.liquidityStrategyConfig;
        if (lsCfg.liquidityStrategy != address(0)) {
            _setupLiquidityStrategy(fpmmProxy, cfg.token0, cfg.token1, lsCfg);
        } else {
            console.log("  > No liquidity strategy configured for FPMM");
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

    function _setupLiquidityStrategy(
        address fpmmProxy,
        address token0,
        address token1,
        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg
    ) internal {
        address strategyAddy = lsCfg.liquidityStrategy;

        if (_isReserveLiquidityStrategy(strategyAddy)) {
            _setupReserveLiquidityStrategy(fpmmProxy, token0, token1, lsCfg);
        } else {
            _setupOpenLiquidityStrategy(fpmmProxy, lsCfg);
        }
    }

    function _isReserveLiquidityStrategy(address strategyAddy) internal view returns (bool) {
        try IReserveLiquidityStrategy(strategyAddy).reserve() returns (IReserveV2) {
            return true;
        } catch {
            return false;
        }
    }

    function _setupReserveLiquidityStrategy(
        address fpmmProxy,
        address token0,
        address token1,
        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg
    ) internal {
        address strategyAddy = lsCfg.liquidityStrategy;
        address collateralToken = lsCfg.debtToken == token0 ? token1 : token0;

        // 1. Register assets and strategy spender on ReserveV2 if not yet registered
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(strategyAddy).reserve();
        console.log("  Registering assets and strategy spender on ReserveV2");
        _registerReserveAssets(reserveV2, lsCfg.debtToken, collateralToken, strategyAddy);

        // 2. Set strategy on the FPMM
        IFPMM(owner.harness(fpmmProxy)).setLiquidityStrategy(strategyAddy, true);
        console.log("  > Set liquidity strategy on FPMM:", strategyAddy);

        // 3. Configure the FPMM as a pool on the strategy
        IReserveLiquidityStrategy(owner.harness(strategyAddy))
            .addPool(_buildAddPoolParams(fpmmProxy, lsCfg));
        console.log("  > Added pool to ReserveLiquidityStrategy");

        // 4. Grant minting and burning rights to the strategy on the debt token
        _grantMinterBurner(lsCfg.debtToken, strategyAddy);

        console.log("\n");
        _verifyReserveLiquidityStrategy(fpmmProxy, token0, token1, lsCfg);

        // Now try to trigger a rebalance through the configured strategy
        _verifyRebalance(fpmmProxy, lsCfg);
    }

    function _setupOpenLiquidityStrategy(
        address fpmmProxy,
        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg
    ) internal {
        address strategyAddy = lsCfg.liquidityStrategy;

        // 1. Set strategy on the FPMM
        IFPMM(owner.harness(fpmmProxy)).setLiquidityStrategy(strategyAddy, true);
        console.log("  > Set liquidity strategy on FPMM:", strategyAddy);

        // 2. Configure the FPMM as a pool on the strategy
        IOpenLiquidityStrategy(owner.harness(strategyAddy))
            .addPool(_buildAddPoolParams(fpmmProxy, lsCfg));
        console.log("  > Added pool to OpenLiquidityStrategy");

        console.log("\n");
        _verifyOpenLiquidityStrategy(fpmmProxy, lsCfg);
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

    function _grantMinterBurner(address debtTokenAddy, address strategyAddy) internal {
        IStableTokenV3 debtToken = IStableTokenV3(debtTokenAddy);
        if (!debtToken.isMinter(strategyAddy)) {
            IStableTokenV3(owner.harness(debtTokenAddy)).setMinter(strategyAddy, true);
            console.log("  > Granted minter to strategy on:", tokenSymbol(debtTokenAddy));
        }
        if (!debtToken.isBurner(strategyAddy)) {
            IStableTokenV3(owner.harness(debtTokenAddy)).setBurner(strategyAddy, true);
            console.log("  > Granted burner to strategy on:", tokenSymbol(debtTokenAddy));
        }
    }

    function _registerReserveAssets(
        IReserveV2 reserveV2,
        address debtToken,
        address collateralToken,
        address strategyAddy
    ) internal {
        address reserveAddy = address(reserveV2);

        if (!reserveV2.isStableAsset(debtToken)) {
            IReserveV2(owner.harness(reserveAddy)).registerStableAsset(debtToken);
            console.log("  > Registered stable asset on ReserveV2:", tokenSymbol(debtToken));
        }

        if (!reserveV2.isCollateralAsset(collateralToken)) {
            IReserveV2(owner.harness(reserveAddy)).registerCollateralAsset(collateralToken);
            console.log("  > Registered collateral asset on ReserveV2:", tokenSymbol(collateralToken));
        }

        if (!reserveV2.isLiquidityStrategySpender(strategyAddy)) {
            IReserveV2(owner.harness(reserveAddy)).registerLiquidityStrategySpender(strategyAddy);
            console.log("  > Registered strategy as spender on ReserveV2:", strategyAddy);
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
        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg
    ) internal view {
        address strategyAddy = lsCfg.liquidityStrategy;
        address collateralToken = lsCfg.debtToken == token0 ? token1 : token0;

        // Verify strategy is set on the FPMM
        require(
            IFPMM(fpmmProxy).liquidityStrategy(strategyAddy), "Verify: strategy not set as liquidity strategy on FPMM"
        );

        // Verify pool is registered on the strategy
        require(
            ILiquidityStrategy(strategyAddy).isPoolRegistered(fpmmProxy),
            "Verify: FPMM not registered as pool on strategy"
        );

        // Verify ReserveV2 asset registration
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(strategyAddy).reserve();
        require(
            reserveV2.isStableAsset(lsCfg.debtToken), "Verify: debtToken not registered as stable asset on ReserveV2"
        );
        require(
            reserveV2.isCollateralAsset(collateralToken),
            "Verify: collateralToken not registered as collateral asset on ReserveV2"
        );

        // Verify strategy is registered as spender on ReserveV2
        require(
            reserveV2.isLiquidityStrategySpender(strategyAddy),
            "Verify: strategy not registered as spender on ReserveV2"
        );

        // Verify minter and burner rights
        IStableTokenV3 debtToken = IStableTokenV3(lsCfg.debtToken);
        require(debtToken.isMinter(strategyAddy), "Verify: strategy not set as minter on debtToken");
        require(debtToken.isBurner(strategyAddy), "Verify: strategy not set as burner on debtToken");
    }

    function _verifyOpenLiquidityStrategy(
        address fpmmProxy,
        IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg
    ) internal view {
        address strategyAddy = lsCfg.liquidityStrategy;

        // Verify strategy is set on the FPMM
        require(
            IFPMM(fpmmProxy).liquidityStrategy(strategyAddy), "Verify: strategy not set as liquidity strategy on FPMM"
        );

        // Verify pool is registered on the strategy
        require(
            ILiquidityStrategy(strategyAddy).isPoolRegistered(fpmmProxy),
            "Verify: FPMM not registered as pool on strategy"
        );
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

    function _verifyRebalance(address fpmmProxy, IMentoConfig.LiquidityStrategyPoolConfig memory lsCfg) internal {
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

        // 3. Trigger rebalance through the liquidity strategy
        {
            (uint256 r0Before, uint256 r1Before,) = fpmm.getReserves();
            ILiquidityStrategy(lsCfg.liquidityStrategy).rebalance(fpmmProxy);
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
