// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IAddressesRegistry} from "lib/bold/contracts/src/Interfaces/IAddressesRegistry.sol";
import {FXPriceFeed} from "bold/src/PriceFeeds/FXPriceFeed.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ReserveTroveFactory} from "src/ReserveTroveFactory.sol";
import {ITroveManager} from "lib/bold/contracts/src/Interfaces/ITroveManager.sol";
import {LatestTroveData} from "lib/bold/contracts/src/Types/LatestTroveData.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IExchangeProvider} from "lib/mento-core/contracts/interfaces/IExchangeProvider.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";

import {LiquidityStrategy} from "lib/mento-core/contracts/liquidityStrategies/LiquidityStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { CeloPrecompiles} from "lib/mento-core/lib/mento-std/src/CeloPrecompiles.sol";
import { MockCELO } from "../../helpers/MockCELO.sol";
import {OracleHelper} from "../../helpers/OracleHelper.sol";

contract MigrateStableToCDP is TrebScript, ProxyHelper, CeloPrecompiles {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    Senders.Sender deployer;
    Senders.Sender migrationOwner;
    IMentoConfig.CDPMigrationConfig cfg;
    IAddressesRegistry registry;
    address owner;
    address fpmm;
    address debtToken;
    address collateralToken;
    address factory;
    address cdpLiquidityStrategy;
    address protocolFeeRecipient;
    address reserveTroveManager;
    uint256 troveId;

    /// @custom:env {string} token
    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        vm.etch(lookup("CELO"), type(MockCELO).runtimeCode);
        vm.makePersistent(lookup("CELO"));

        OracleHelper.refreshOracleRatesIfFork(lookupProxyOrFail("SortedOracles"), Config.get());

        cfg = Config.get().getCDPMigrationConfig(vm.envString("token"));
        deployer = sender("deployer");
        migrationOwner = sender("migrationOwner");
        owner = migrationOwner.account;

        registry = IAddressesRegistry(lookupOrFail(string.concat("AddressesRegistry:v3.0.0-", vm.envString("token"))));
        // 1. Setup — look up core addresses
        address fpmmFactoryAddy = lookupProxyOrFail("FPMMFactory");
        fpmm = IFPMMFactory(fpmmFactoryAddy).getPool(address(registry.boldToken()), address(registry.collToken()));
        require(fpmm != address(0), "FPMM not found");

        debtToken = address(registry.boldToken());
        collateralToken = address(registry.collToken());
        cdpLiquidityStrategy = lookupProxyOrFail("CDPLiquidityStrategy");
        protocolFeeRecipient = lookupOrFail("ProtocolFeeRecipient");
        reserveTroveManager = lookupOrFail("ReserveSafe");

        _destroyV2Exchange();
        _updateDebtTokenRoles();
        _enableCDPLiquidityStrategy();
        _deployReserveTroveFactory();
        _setRateFeedID();
        _createReserveTrove();

        _postChecks();
    }

    function _destroyV2Exchange() internal {
        address biPoolManagerAddy = lookupOrFail("Proxy:BiPoolManager");
        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManagerAddy);
        IBiPoolManager biPoolManager = IBiPoolManager(migrationOwner.harness(biPoolManagerAddy));

        IExchangeProvider.Exchange[] memory exchanges = biPoolManagerRead.getExchanges();

        for (uint256 i = 0; i < exchanges.length; i++) {
            IExchangeProvider.Exchange memory exchange = exchanges[i];
            bool matchesTokens = (exchange.assets[0] == debtToken && exchange.assets[1] == collateralToken) ||
                (exchange.assets[0] == collateralToken && exchange.assets[1] == debtToken);

            if (matchesTokens) {
                biPoolManager.destroyExchange(exchange.exchangeId, i);
                return;
            }
        }

        revert("No matching V2 exchange found on BiPoolManager");
    }

    function _updateDebtTokenRoles() internal {
        // Remove broker permissions on debt token
        address broker = lookupOrFail("Proxy:Broker");
        IStableTokenV3(migrationOwner.harness(debtToken)).setMinter(broker, false);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(broker, false);

        // Grant Liquity contracts permissions on debt token
        IStableTokenV3(migrationOwner.harness(debtToken)).setMinter(address(registry.borrowerOperations()), true);
        IStableTokenV3(migrationOwner.harness(debtToken)).setMinter(address(registry.activePool()), true);

        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(address(registry.collateralRegistry()), true);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(address(registry.borrowerOperations()), true);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(address(registry.troveManager()), true);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(address(registry.stabilityPool()), true);

        IStableTokenV3(migrationOwner.harness(debtToken)).setOperator(address(registry.stabilityPool()), true);
    }

    function _enableCDPLiquidityStrategy() internal {
        // Enable CDP strategy on FPMM and add pool config
        IFPMM(migrationOwner.harness(fpmm)).setLiquidityStrategy(cdpLiquidityStrategy, true);

        ILiquidityStrategy.AddPoolParams memory params = ILiquidityStrategy.AddPoolParams({
            pool: fpmm,
            debtToken: debtToken,
            cooldown: cfg.cooldown,
            protocolFeeRecipient: protocolFeeRecipient,
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

        ICDPLiquidityStrategy(migrationOwner.harness(cdpLiquidityStrategy)).addPool(params, cdpConfig);
    }

    function _setRateFeedID() internal {
        address priceFeed = address(registry.priceFeed());
        FXPriceFeed(migrationOwner.harness(priceFeed)).setRateFeedID(cfg.rateFeedID);
    }

    function _deployReserveTroveFactory() internal {
        factory = lookup("ReserveTroveFactory");
        if (factory == address(0)) {
            factory = deployer.create3("ReserveTroveFactory").deploy(
                abi.encode(reserveTroveManager, owner)
            );
        }
    }

    function _createReserveTrove() internal {
        // Grant factory temporary permissions
        IStableTokenV3(migrationOwner.harness(collateralToken)).setMinter(factory, true);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(factory, true);

        // Fund factory with gas token for ETH_GAS_COMPENSATION
        uint256 gasCompensation = registry.stabilityPool().systemParams().ETH_GAS_COMPENSATION();
        IERC20(migrationOwner.harness(address(registry.gasToken()))).transfer(factory, gasCompensation);

        // Create reserve trove
        troveId = ReserveTroveFactory(payable(migrationOwner.harness(factory))).createReserveTrove(
            registry,
            cfg.collateralizationRatio,
            cfg.interestRate
        );

        // Cleanup — remove temporary permissions
        IStableTokenV3(migrationOwner.harness(collateralToken)).setMinter(factory, false);
        IStableTokenV3(migrationOwner.harness(debtToken)).setBurner(factory, false);
    }

    function _postChecks() internal view {
        _checkV2ExchangeDestroyed();
        _checkDebtTokenRoles();
        _checkLiquidityStrategy();
        _checkCDPLiquidityStrategyConfig();
        _checkRateFeedID();
        _checkReserveTrove();
        _checkFactoryCleanup();
    }

    function _checkV2ExchangeDestroyed() internal view {
        address biPoolManagerAddy = lookupOrFail("Proxy:BiPoolManager");
        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManagerAddy);

        IExchangeProvider.Exchange[] memory exchanges = biPoolManagerRead.getExchanges();

        for (uint256 i = 0; i < exchanges.length; i++) {
            IExchangeProvider.Exchange memory exchange = exchanges[i];
            bool matchesTokens = (exchange.assets[0] == debtToken && exchange.assets[1] == collateralToken) ||
                (exchange.assets[0] == collateralToken && exchange.assets[1] == debtToken);
            require(!matchesTokens, "V2 exchange still exists on BiPoolManager");
        }
    }

    function _checkDebtTokenRoles() internal view {
        IStableTokenV3 debt = IStableTokenV3(debtToken);

        // Broker should have minter and burner permissions
        address broker = lookupOrFail("Proxy:Broker");
        require(!debt.isMinter(broker), "Broker not a minter on debt token");
        require(!debt.isBurner(broker), "Broker not a burner on debt token");

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
        // CDP strategy should be enabled on FPMM and have pool registered
        require(IFPMM(fpmm).liquidityStrategy(cdpLiquidityStrategy), "CDP strategy not enabled on FPMM");
        require(
            ILiquidityStrategy(cdpLiquidityStrategy).isPoolRegistered(fpmm),
            "FPMM not registered on CDP strategy"
        );
    }

    function _checkCDPLiquidityStrategyConfig() internal view {
        // Check pool config
        (
            bool isToken0Debt,
            ,  // lastRebalance
            uint32 rebalanceCooldown,
            address actualProtocolFeeRecipient,
            uint64 liquiditySourceIncentiveExpansion,
            uint64 protocolIncentiveExpansion,
            uint64 liquiditySourceIncentiveContraction,
            uint64 protocolIncentiveContraction
        ) = LiquidityStrategy(cdpLiquidityStrategy).poolConfigs(fpmm);

        bool expectedIsToken0Debt = (IFPMM(fpmm).token0() == address(registry.boldToken()));
        require(isToken0Debt == expectedIsToken0Debt, "PoolConfig isToken0Debt mismatch");
        require(rebalanceCooldown == cfg.cooldown, "PoolConfig cooldown mismatch");
        require(actualProtocolFeeRecipient == protocolFeeRecipient, "PoolConfig protocolFeeRecipient mismatch");
        require(
            liquiditySourceIncentiveExpansion == cfg.liquiditySourceIncentiveExpansion,
            "PoolConfig liquiditySourceIncentiveExpansion mismatch"
        );
        require(protocolIncentiveExpansion == cfg.protocolIncentiveExpansion, "PoolConfig protocolIncentiveExpansion mismatch");
        require(
            liquiditySourceIncentiveContraction == cfg.liquiditySourceIncentiveContraction,
            "PoolConfig liquiditySourceIncentiveContraction mismatch"
        );
        require(
            protocolIncentiveContraction == cfg.protocolIncentiveContraction,
            "PoolConfig protocolIncentiveContraction mismatch"
        );

        // Check CDP-specific config
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
            troveManager.troveNFT().ownerOf(troveId) == reserveTroveManager,
            "Reserve trove NFT not owned by reserveTroveManager"
        );

        // Trove debt should be at least the debt token total supply (includes upfront fee)
        uint256 totalSupply = IStableTokenV3(debtToken).totalSupply();
        console.log("debt token total supply", totalSupply);
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
        // Temporary permissions should be removed
        require(!IStableTokenV3(collateralToken).isMinter(factory), "Factory still a minter on collateral token");
        require(!IStableTokenV3(debtToken).isBurner(factory), "Factory still a burner on debt token");
    }
}
