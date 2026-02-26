// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

import {ICDPMigrationConfig} from "script/config/ICDPMigrationConfig.sol";
import {CDPMigrationConfigLib} from "script/config/CDPMigrationConfig.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IAddressesRegistry} from "lib/bold/contracts/src/Interfaces/IAddressesRegistry.sol";
import {FXPriceFeed} from "bold/src/PriceFeeds/FXPriceFeed.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";
import {ReserveTroveFactory} from "src/ReserveTroveFactory.sol";
import {ITroveManager} from "lib/bold/contracts/src/Interfaces/ITroveManager.sol";
import {LatestTroveData} from "lib/bold/contracts/src/Types/LatestTroveData.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MigrateStableToCDP is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    Senders.Sender deployer;
    ICDPMigrationConfig.CDPMigrationInstanceConfig cfg;
    IAddressesRegistry registry;
    address fpmm;
    address debtToken;
    address collateralToken;
    address factory;
    address reserveLiquidityStrategy;
    address cdpLiquidityStrategy;
    uint256 troveId;

    /// @custom:senders deployer
    function run() public broadcast {
        cfg = CDPMigrationConfigLib.get();
        deployer = sender("deployer");

        // 1. Setup — look up core addresses
        registry = IAddressesRegistry(lookupOrFail(cfg.addressesRegistryLabel));
        fpmm = lookupOrFail(cfg.fpmmLabel);
        debtToken = address(registry.boldToken());
        collateralToken = address(registry.collToken());
        reserveLiquidityStrategy = lookupOrFail(cfg.reserveLiquidityStrategyLabel);
        cdpLiquidityStrategy = lookupOrFail(cfg.cdpLiquidityStrategyLabel);

        _updateDebtTokenRoles();
        _switchLiquidityStrategy();
        _deployReserveTroveFactory();
        _setRateFeedID();
        _createReserveTrove();

        _postChecks();
    }

    function _updateDebtTokenRoles() internal {
        // Remove reserve strategy minter on debt token
        IStableTokenV3(deployer.harness(debtToken)).setMinter(reserveLiquidityStrategy, false);

        // Grant Liquity contracts permissions on debt token
        IStableTokenV3(deployer.harness(debtToken)).setMinter(address(registry.borrowerOperations()), true);
        IStableTokenV3(deployer.harness(debtToken)).setMinter(address(registry.activePool()), true);

        IStableTokenV3(deployer.harness(debtToken)).setBurner(address(registry.collateralRegistry()), true);
        IStableTokenV3(deployer.harness(debtToken)).setBurner(address(registry.borrowerOperations()), true);
        IStableTokenV3(deployer.harness(debtToken)).setBurner(address(registry.troveManager()), true);
        IStableTokenV3(deployer.harness(debtToken)).setBurner(address(registry.stabilityPool()), true);

        IStableTokenV3(deployer.harness(debtToken)).setOperator(address(registry.stabilityPool()), true);
    }

    function _switchLiquidityStrategy() internal {
        // Remove reserve strategy pool config and disable on FPMM
        IReserveLiquidityStrategy(deployer.harness(reserveLiquidityStrategy)).removePool(fpmm);
        IFPMM(deployer.harness(fpmm)).setLiquidityStrategy(reserveLiquidityStrategy, false);

        // Enable CDP strategy on FPMM and add pool config
        IFPMM(deployer.harness(fpmm)).setLiquidityStrategy(cdpLiquidityStrategy, true);

        ILiquidityStrategy.AddPoolParams memory params = ILiquidityStrategy.AddPoolParams({
            pool: fpmm,
            debtToken: debtToken,
            cooldown: cfg.cooldown,
            protocolFeeRecipient: cfg.protocolFeeRecipient,
            liquiditySourceIncentiveExpansion: cfg.liquiditySourceIncentiveExpansion,
            protocolIncentiveExpansion: cfg.protocolIncentiveExpansion,
            liquiditySourceIncentiveContraction: cfg.liquiditySourceIncentiveContraction,
            protocolIncentiveContraction: cfg.protocolIncentiveContraction
        });

        ICDPLiquidityStrategy.CDPConfig memory cdpConfig = ICDPLiquidityStrategy.CDPConfig({
            stabilityPool: address(registry.stabilityPool()),
            collateralRegistry: address(registry.collateralRegistry()),
            stabilityPoolPercentage: cfg.stabilityPoolPercentage,
            maxIterations: cfg.maxIterations
        });

        ICDPLiquidityStrategy(deployer.harness(cdpLiquidityStrategy)).addPool(params, cdpConfig);
    }

    function _setRateFeedID() internal {
        address priceFeed = address(registry.priceFeed());
        FXPriceFeed(deployer.harness(priceFeed)).setRateFeedID(cfg.rateFeedID);
    }

    function _deployReserveTroveFactory() internal {
        factory = lookup("ReserveTroveFactory");
        if (factory == address(0)) {
            factory = deployer.create3("ReserveTroveFactory").deploy(
                abi.encode(cfg.reserveTroveManagerAddress, deployer.account)
            );
        }
    }

    function _createReserveTrove() internal {
        // Grant factory temporary permissions
        IStableTokenV3(deployer.harness(collateralToken)).setMinter(factory, true);
        IStableTokenV3(deployer.harness(debtToken)).setBurner(factory, true);

        // Fund factory with gas token for ETH_GAS_COMPENSATION
        uint256 gasCompensation = registry.stabilityPool().systemParams().ETH_GAS_COMPENSATION();
        IERC20(deployer.harness(address(registry.gasToken()))).transfer(factory, gasCompensation);

        // Create reserve trove
        troveId = ReserveTroveFactory(payable(deployer.harness(factory))).createReserveTrove(
            registry,
            cfg.collateralizationRatio,
            cfg.interestRate
        );

        // Cleanup — remove temporary permissions
        IStableTokenV3(deployer.harness(collateralToken)).setMinter(factory, false);
        IStableTokenV3(deployer.harness(debtToken)).setBurner(factory, false);
    }

    function _postChecks() internal view {
        _checkDebtTokenRoles();
        _checkLiquidityStrategy();
        _checkCDPLiquidityStrategyConfig();
        _checkRateFeedID();
        _checkReserveTrove();
        _checkFactoryCleanup();
    }

    function _checkDebtTokenRoles() internal view {
        IStableTokenV3 debt = IStableTokenV3(debtToken);

        // Reserve strategy should no longer be a minter
        require(!debt.isMinter(reserveLiquidityStrategy), "Reserve strategy still a minter on debt token");

        // Liquity contracts should have minter permissions
        require(debt.isMinter(address(registry.borrowerOperations())), "BorrowerOperations not a minter on debt token");
        require(debt.isMinter(address(registry.activePool())), "ActivePool not a minter on debt token");

        // Liquity contracts should have burner permissions
        require(debt.isBurner(address(registry.collateralRegistry())), "CollateralRegistry not a burner on debt token");
        require(debt.isBurner(address(registry.borrowerOperations())), "BorrowerOperations not a burner on debt token");
        require(debt.isBurner(address(registry.troveManager())), "TroveManager not a burner on debt token");
        require(debt.isBurner(address(registry.stabilityPool())), "StabilityPool not a burner on debt token");

        // StabilityPool should be an operator
        require(debt.isOperator(address(registry.stabilityPool())), "StabilityPool not an operator on debt token");
    }

    function _checkLiquidityStrategy() internal view {
        // Reserve strategy should be disabled on FPMM and have no pool registered
        require(!IFPMM(fpmm).liquidityStrategy(reserveLiquidityStrategy), "Reserve strategy still enabled on FPMM");
        require(
            !ILiquidityStrategy(reserveLiquidityStrategy).isPoolRegistered(fpmm),
            "FPMM still registered on reserve strategy"
        );

        // CDP strategy should be enabled on FPMM and have pool registered
        require(IFPMM(fpmm).liquidityStrategy(cdpLiquidityStrategy), "CDP strategy not enabled on FPMM");
        require(
            ILiquidityStrategy(cdpLiquidityStrategy).isPoolRegistered(fpmm),
            "FPMM not registered on CDP strategy"
        );
    }

    function _checkCDPLiquidityStrategyConfig() internal view {
        ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
            ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(fpmm);

        require(
            cdpConfig.stabilityPool == address(registry.stabilityPool()),
            "CDPConfig stabilityPool mismatch"
        );
        require(
            cdpConfig.collateralRegistry == address(registry.collateralRegistry()),
            "CDPConfig collateralRegistry mismatch"
        );
        require(cdpConfig.stabilityPoolPercentage == cfg.stabilityPoolPercentage, "CDPConfig stabilityPoolPercentage mismatch");
        require(cdpConfig.maxIterations == cfg.maxIterations, "CDPConfig maxIterations mismatch");
    }

    function _checkReserveTrove() internal view {
        ITroveManager troveManager = registry.troveManager();

        // Trove should be active with correct interest rate
        require(
            troveManager.getTroveStatus(troveId) == ITroveManager.Status.active,
            "Reserve trove is not active"
        );
        require(
            troveManager.getTroveAnnualInterestRate(troveId) == cfg.interestRate,
            "Reserve trove interest rate mismatch"
        );

        // Trove NFT should be owned by the reserve trove manager
        require(
            troveManager.troveNFT().ownerOf(troveId) == cfg.reserveTroveManagerAddress,
            "Reserve trove NFT not owned by reserveTroveManager"
        );

        // Trove debt should be at least the debt token total supply (includes upfront fee)
        uint256 totalSupply = IStableTokenV3(debtToken).totalSupply();
        LatestTroveData memory troveData = troveManager.getLatestTroveData(troveId);
        require(troveData.entireDebt >= totalSupply, "Reserve trove debt less than total supply");
        require(troveData.entireColl > 0, "Reserve trove has no collateral");
    }

    function _checkRateFeedID() internal view {
        address priceFeed = address(registry.priceFeed());
        require(
            FXPriceFeed(priceFeed).rateFeedID() == cfg.rateFeedID,
            "FXPriceFeed rateFeedID mismatch"
        );
    }

    function _checkFactoryCleanup() internal view {
        // Factory should be deployed
        require(factory != address(0), "ReserveTroveFactory not deployed");
        require(factory.code.length > 0, "ReserveTroveFactory has no code");

        // Temporary permissions should be removed
        require(!IStableTokenV3(collateralToken).isMinter(factory), "Factory still a minter on collateral token");
        require(!IStableTokenV3(debtToken).isBurner(factory), "Factory still a burner on debt token");
    }
}
