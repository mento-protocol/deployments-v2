// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
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

contract CreateFPMM is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public virtual broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address factoryAddy = lookupProxyOrFail("FPMMFactory");
        IFPMMFactory factory = IFPMMFactory(deployer.harness(factoryAddy));
        IFPMMFactory factoryView = IFPMMFactory(factoryAddy);

        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            _deployFPMM(deployer, factory, factoryView, fpmmConfigs[i]);
        }
    }

    function _deployFPMM(
        Senders.Sender storage deployer,
        IFPMMFactory factory,
        IFPMMFactory factoryView,
        IMentoConfig.FPMMConfig memory c
    ) internal {
        address existingPool = factoryView.getPool(c.token0, c.token1);
        address owner = deployer.account;

        if (existingPool != address(0)) revert("FPMM already exists");

        address proxy = factory.deployFPMM(
            c.fpmmImplementation,
            c.oracleAdapter,
            c.proxyAdmin,
            owner,
            c.token0,
            c.token1,
            c.referenceRateFeedID,
            c.invertRateFeed,
            c.params
        );

        console.log("Created FPMM pool:");
        console.log("  proxy:", proxy);
        console.log("  token0:", c.token0);
        console.log("  token1:", c.token1);
        console.log("  referenceRateFeedID:", c.referenceRateFeedID);
        console.log("  invertRateFeed:", c.invertRateFeed);


        _mintInitialLiquidity(deployer, proxy, c);

        if (c.useReserveLiquidityStrategy) {
            _setupReserveLiquidityStrategy(
                deployer,
                proxy,
                c.token0,
                c.token1,
                c.rlsConfig
            );
        }

        _verifyFPMM(factoryView, proxy, c);
        _verifyInitialLiquidity(proxy, deployer.account);

        if (c.useReserveLiquidityStrategy) {
            _verifyReserveLiquidityStrategy(
                proxy,
                c.token0,
                c.token1,
                c.rlsConfig
            );
        }
    }

    function _setupReserveLiquidityStrategy(
        Senders.Sender storage deployer,
        address fpmmProxy,
        address token0,
        address token1,
        IMentoConfig.ReserveLiquidityStrategyPoolConfig memory rls
    ) internal {
        address rlsAddy = rls.reserveLiquidityStrategy;
        address collateralToken = rls.debtToken == token0 ? token1 : token0;

        // 1. Register assets and RLS spender on ReserveV2 if not yet registered
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(rlsAddy).reserve();
        _registerReserveAssets(deployer, reserveV2, rls.debtToken, collateralToken, rlsAddy);

        // 2. Set RLS as liquidity strategy on the FPMM
        IFPMM(deployer.harness(fpmmProxy)).setLiquidityStrategy(rlsAddy, true);
        console.log("  Set liquidity strategy on FPMM:", rlsAddy);

        // 3. Configure the FPMM as a pool on the RLS
        IReserveLiquidityStrategy(deployer.harness(rlsAddy)).addPool(
            ILiquidityStrategy.AddPoolParams({
                pool: fpmmProxy,
                debtToken: rls.debtToken,
                cooldown: rls.cooldown,
                protocolFeeRecipient: rls.protocolFeeRecipient,
                liquiditySourceIncentiveExpansion: rls
                    .liquiditySourceIncentiveExpansion,
                protocolIncentiveExpansion: rls.protocolIncentiveExpansion,
                liquiditySourceIncentiveContraction: rls
                    .liquiditySourceIncentiveContraction,
                protocolIncentiveContraction: rls.protocolIncentiveContraction
            })
        );
        console.log("  Added pool to ReserveLiquidityStrategy");

        // 4. Grant minting and burning rights to the strategy on the debt token
        IStableTokenV3 debtToken = IStableTokenV3(rls.debtToken);
        if (!debtToken.isMinter(rlsAddy)) {
            IStableTokenV3(deployer.harness(rls.debtToken)).setMinter(rlsAddy, true);
            console.log("  Granted minter to strategy on:", rls.debtToken);
        }
        if (!debtToken.isBurner(rlsAddy)) {
            IStableTokenV3(deployer.harness(rls.debtToken)).setBurner(rlsAddy, true);
            console.log("  Granted burner to strategy on:", rls.debtToken);
        }
    }

    function _registerReserveAssets(
        Senders.Sender storage deployer,
        IReserveV2 reserveV2,
        address debtToken,
        address collateralToken,
        address rlsAddy
    ) internal {
        address reserveAddy = address(reserveV2);

        if (!reserveV2.isStableAsset(debtToken)) {
            IReserveV2(deployer.harness(reserveAddy)).registerStableAsset(debtToken);
            console.log("  Registered stable asset on ReserveV2:", debtToken);
        }

        if (!reserveV2.isCollateralAsset(collateralToken)) {
            IReserveV2(deployer.harness(reserveAddy)).registerCollateralAsset(collateralToken);
            console.log("  Registered collateral asset on ReserveV2:", collateralToken);
        }

        if (!reserveV2.isLiquidityStrategySpender(rlsAddy)) {
            IReserveV2(deployer.harness(reserveAddy)).registerLiquidityStrategySpender(rlsAddy);
            console.log("  Registered RLS as spender on ReserveV2:", rlsAddy);
        }
    }

    function _mintInitialLiquidity(
        Senders.Sender storage deployer,
        address fpmmProxy,
        IMentoConfig.FPMMConfig memory c
    ) internal {
        IFPMM fpmm = IFPMM(fpmmProxy);
        address sorted0 = fpmm.token0();
        address sorted1 = fpmm.token1();

        // Get the oracle rate (token0/token1 after invertRateFeed)
        IOracleAdapter oracle = fpmm.oracleAdapter();
        (uint256 rateNumerator, uint256 rateDenominator) = oracle
            .getFXRateIfValid(c.referenceRateFeedID);
        if (c.invertRateFeed) {
            (rateNumerator, rateDenominator) = (rateDenominator, rateNumerator);
        }

        uint256 decimals0 = 10 ** IERC20Metadata(sorted0).decimals();
        uint256 decimals1 = 10 ** IERC20Metadata(sorted1).decimals();

        // 1 unit of token1 (collateral)
        uint256 amount1 = decimals1;
        // Convert to value-equivalent amount of token0 using oracle rate
        // rate = token0_price / token1_price, so amount0 = amount1 * rateDenominator * decimals0 / (rateNumerator * decimals1)
        uint256 amount0 = (amount1 * rateDenominator * decimals0) /
            (rateNumerator * decimals1);

        require(
            IERC20(sorted0).balanceOf(deployer.account) >= amount0,
            "Deployer has insufficient token0 balance for initial liquidity"
        );
        require(
            IERC20(sorted1).balanceOf(deployer.account) >= amount1,
            "Deployer has insufficient token1 balance for initial liquidity"
        );

        // Transfer tokens to the FPMM and mint
        IERC20(deployer.harness(sorted0)).transfer(fpmmProxy, amount0);
        IERC20(deployer.harness(sorted1)).transfer(fpmmProxy, amount1);
        uint256 liquidity = IFPMM(deployer.harness(fpmmProxy)).mint(
            deployer.account
        );

        console.log("  Minted initial liquidity:", liquidity);
        console.log("    amount0:", amount0);
        console.log("    amount1:", amount1);
        console.log("    liquidity:", liquidity);
    }

    // ========== Verification ==========

    function _verifyFPMM(
        IFPMMFactory factoryView,
        address proxy,
        IMentoConfig.FPMMConfig memory c
    ) internal view {
        require(
            factoryView.isPool(proxy),
            "Verify: factory does not report pool as deployed"
        );

        IFPMM fpmm = IFPMM(proxy);

        (address sorted0, address sorted1) = factoryView.sortTokens(
            c.token0,
            c.token1
        );
        require(
            fpmm.token0() == sorted0 && fpmm.token1() == sorted1,
            "Verify: FPMM token addresses mismatch"
        );

        require(
            fpmm.referenceRateFeedID() == c.referenceRateFeedID,
            "Verify: FPMM referenceRateFeedID mismatch"
        );
        require(
            fpmm.invertRateFeed() == c.invertRateFeed,
            "Verify: FPMM invertRateFeed mismatch"
        );
        require(
            address(fpmm.oracleAdapter()) == c.oracleAdapter,
            "Verify: FPMM oracleAdapter mismatch"
        );
        require(
            getProxyAdmin(proxy) == c.proxyAdmin,
            "Verify: FPMM proxyAdmin mismatch"
        );

        _verifyFPMMParams(fpmm, c.params);
    }

    function _verifyFPMMParams(
        IFPMM fpmm,
        IFPMM.FPMMParams memory p
    ) internal view {
        require(
            fpmm.lpFee() == p.lpFee,
            "Verify: FPMM lpFee mismatch"
        );
        require(
            fpmm.protocolFee() == p.protocolFee,
            "Verify: FPMM protocolFee mismatch"
        );
        require(
            fpmm.protocolFeeRecipient() == p.protocolFeeRecipient,
            "Verify: FPMM protocolFeeRecipient mismatch"
        );
        require(
            fpmm.feeSetter() == p.feeSetter,
            "Verify: FPMM feeSetter mismatch"
        );
        require(
            fpmm.rebalanceIncentive() == p.rebalanceIncentive,
            "Verify: FPMM rebalanceIncentive mismatch"
        );
        require(
            fpmm.rebalanceThresholdAbove() == p.rebalanceThresholdAbove,
            "Verify: FPMM rebalanceThresholdAbove mismatch"
        );
        require(
            fpmm.rebalanceThresholdBelow() == p.rebalanceThresholdBelow,
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
        require(
            IFPMM(fpmmProxy).liquidityStrategy(rlsAddy),
            "Verify: RLS not set as liquidity strategy on FPMM"
        );

        // Verify pool is registered on the RLS
        require(
            ILiquidityStrategy(rlsAddy).isPoolRegistered(fpmmProxy),
            "Verify: FPMM not registered as pool on RLS"
        );

        // Verify ReserveV2 asset registration
        IReserveV2 reserveV2 = IReserveLiquidityStrategy(rlsAddy).reserve();
        require(
            reserveV2.isStableAsset(rls.debtToken),
            "Verify: debtToken not registered as stable asset on ReserveV2"
        );
        require(
            reserveV2.isCollateralAsset(collateralToken),
            "Verify: collateralToken not registered as collateral asset on ReserveV2"
        );

        // Verify RLS is registered as spender on ReserveV2
        require(
            reserveV2.isLiquidityStrategySpender(rlsAddy),
            "Verify: RLS not registered as spender on ReserveV2"
        );

        // Verify minter and burner rights
        IStableTokenV3 debtToken = IStableTokenV3(rls.debtToken);
        require(
            debtToken.isMinter(rlsAddy),
            "Verify: RLS not set as minter on debtToken"
        );
        require(
            debtToken.isBurner(rlsAddy),
            "Verify: RLS not set as burner on debtToken"
        );
    }

    function _verifyInitialLiquidity(
        address fpmmProxy,
        address deployer
    ) internal view {
        IFPMM fpmm = IFPMM(fpmmProxy);

        // Verify reserves are non-zero
        (uint256 r0, uint256 r1, ) = fpmm.getReserves();
        require(r0 > 0, "Verify: FPMM reserve0 is zero after mint");
        require(r1 > 0, "Verify: FPMM reserve1 is zero after mint");

        // Verify LP total supply is non-zero and deployer received LP tokens
        IERC20 lpToken = IERC20(fpmmProxy);
        require(
            lpToken.totalSupply() > 0,
            "Verify: FPMM totalSupply is zero after mint"
        );
        require(
            lpToken.balanceOf(deployer) > 0,
            "Verify: deployer received no LP tokens"
        );
    }
}
