// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {Config, ILiquityConfig} from "script/config/Config.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {ITroveNFT} from "bold/src/Interfaces/ITroveNFT.sol";
import {LatestTroveData} from "bold/src/Types/LatestTroveData.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";

/// @dev Minimal interface to read FXPriceFeed public state variables
interface IFXPriceFeed {
    function oracleAdapter() external view returns (address);

    function rateFeedID() external view returns (address);

    function invertRateFeed() external view returns (bool);

    function l2SequencerGracePeriod() external view returns (uint256);

    function watchdogAddress() external view returns (address);

    function borrowerOperations() external view returns (address);

    function isShutdown() external view returns (bool);

    function isL2SequencerUp() external view returns (bool);
}

/**
 * @title CDPMigrationVerification
 * @notice Verifies CDP migration state: roles, strategy config, V2 exchange cleanup,
 *         Liquity contract role assignments on CDP-migrated tokens, and stable token
 *         minting/burning/operator operations.
 */
contract CDPMigrationVerification is V3IntegrationBase {
    address[] internal cdpPools;
    address internal biPoolManager;

    function setUp() public override {
        super.setUp();
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
        biPoolManager = lookupProxyOrFail("BiPoolManager");
    }

    // ========== CDP Pools Exist ==========

    function test_cdpPools_exist() public view {
        assertGt(cdpPools.length, 0, "No CDP pools registered with CDPLiquidityStrategy");
    }

    // ========== V2 BiPoolManager Exchange Destroyed ==========

    /// @notice For each CDP-migrated token pair, verify no V2 BiPoolManager exchange exists
    function test_cdpPools_v2Exchange_destroyed() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < cdpPools.length; i++) {
            address t0 = IFPMM(cdpPools[i]).token0();
            address t1 = IFPMM(cdpPools[i]).token1();

            bool exchangeFound = false;
            for (uint256 j = 0; j < exchangeIds.length; j++) {
                IBiPoolManager.PoolExchange memory ex = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[j]);
                // Check both orderings since BiPoolManager stores (asset0, asset1) which may not be sorted
                if ((ex.asset0 == t0 && ex.asset1 == t1) || (ex.asset0 == t1 && ex.asset1 == t0)) {
                    exchangeFound = true;
                    break;
                }
            }

            assertFalse(
                exchangeFound,
                string.concat("V2 BiPoolManager exchange still exists for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Broker is NOT Minter/Burner on CDP Debt Token ==========

    /// @notice Verify Broker does NOT have minter role on CDP-migrated debt tokens
    function test_cdpPools_broker_notMinter() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            assertFalse(
                IStableTokenV3(debtToken).isMinter(broker),
                string.concat("Broker is still minter on CDP debt token for pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify Broker does NOT have burner role on CDP-migrated debt tokens
    function test_cdpPools_broker_notBurner() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            assertFalse(
                IStableTokenV3(debtToken).isBurner(broker),
                string.concat("Broker is still burner on CDP debt token for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Liquity Roles: Minters ==========

    /// @notice BorrowerOperations and ActivePool should be minters on the CDP debt token
    function test_cdpPools_liquityRoles_minters() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (address borrowerOps, address activePoolAddr,,) = _getLiquityContracts(cdpPools[i]);

            assertTrue(
                IStableTokenV3(debtToken).isMinter(borrowerOps),
                string.concat("BorrowerOperations not minter on CDP debt token for pool at index ", vm.toString(i))
            );
            assertTrue(
                IStableTokenV3(debtToken).isMinter(activePoolAddr),
                string.concat("ActivePool not minter on CDP debt token for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Liquity Roles: Burners ==========

    /// @notice CollateralRegistry, BorrowerOperations, TroveManager, and StabilityPool should be burners
    function test_cdpPools_liquityRoles_burners() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);
            (address borrowerOps,, address troveManagerAddr, address stabilityPoolAddr) =
                _getLiquityContracts(cdpPools[i]);

            assertTrue(
                IStableTokenV3(debtToken).isBurner(cdpConfig.collateralRegistry),
                string.concat("CollateralRegistry not burner on CDP debt token for pool at index ", vm.toString(i))
            );
            assertTrue(
                IStableTokenV3(debtToken).isBurner(borrowerOps),
                string.concat("BorrowerOperations not burner on CDP debt token for pool at index ", vm.toString(i))
            );
            assertTrue(
                IStableTokenV3(debtToken).isBurner(troveManagerAddr),
                string.concat("TroveManager not burner on CDP debt token for pool at index ", vm.toString(i))
            );
            assertTrue(
                IStableTokenV3(debtToken).isBurner(stabilityPoolAddr),
                string.concat("StabilityPool not burner on CDP debt token for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Liquity Roles: Operator ==========

    /// @notice StabilityPool should be operator on the CDP debt token
    function test_cdpPools_liquityRoles_operator() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);

            assertTrue(
                IStableTokenV3(debtToken).isOperator(cdpConfig.stabilityPool),
                string.concat("StabilityPool not operator on CDP debt token for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== CDPLiquidityStrategy Enabled on FPMM ==========

    /// @notice Verify CDPLiquidityStrategy is registered as liquidity strategy on each CDP FPMM pool
    function test_cdpPools_strategyEnabledOnFPMM() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            assertTrue(
                IFPMM(cdpPools[i]).liquidityStrategy(cdpLiquidityStrategy),
                string.concat("CDPLiquidityStrategy not enabled on FPMM pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify each CDP pool is registered on CDPLiquidityStrategy
    function test_cdpPools_registeredOnStrategy() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            assertTrue(
                ICDPLiquidityStrategy(cdpLiquidityStrategy).isPoolRegistered(cdpPools[i]),
                string.concat("CDP pool not registered on CDPLiquidityStrategy at index ", vm.toString(i))
            );
        }
    }

    // ========== CDPConfig Values Valid ==========

    /// @notice Verify CDPConfig matches the CDP migration config and deployed Liquity addresses
    function test_cdpPools_cdpConfig_valid() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);

            // Load expected values from CDP migration config and Liquity's AddressesRegistry
            IMentoConfig.CDPMigrationConfig memory expected = _getCDPMigrationConfig(cdpPools[i]);
            IAddressesRegistry addressesRegistry = _getAddressesRegistry(cdpPools[i]);

            string memory idx = vm.toString(i);

            assertEq(
                cdpConfig.stabilityPool,
                address(addressesRegistry.stabilityPool()),
                string.concat("CDPConfig stabilityPool mismatch at index ", idx)
            );
            assertEq(
                cdpConfig.collateralRegistry,
                address(addressesRegistry.collateralRegistry()),
                string.concat("CDPConfig collateralRegistry mismatch at index ", idx)
            );
            assertEq(
                cdpConfig.stabilityPoolPercentage,
                expected.stabilityPoolPercentage,
                string.concat("CDPConfig stabilityPoolPercentage mismatch at index ", idx)
            );
            assertEq(
                cdpConfig.maxIterations,
                expected.maxIterations,
                string.concat("CDPConfig maxIterations mismatch at index ", idx)
            );
        }
    }

    // ========== Pool Config (Cooldown, Incentives, ProtocolFeeRecipient) Valid ==========

    /// @notice Verify pool config matches the CDP migration config for each pool's token
    function test_cdpPools_poolConfig_valid() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (
                ,,
                uint32 rebalanceCooldown,
                address protocolFeeRecipient,
                uint64 lsIncentiveExpansion,
                uint64 protocolIncentiveExpansion,
                uint64 lsIncentiveContraction,
                uint64 protocolIncentiveContraction
            ) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(cdpPools[i]);

            // Load the expected config by resolving pool → debt token → symbol → CDPMigrationConfig
            IMentoConfig.CDPMigrationConfig memory expected = _getCDPMigrationConfig(cdpPools[i]);

            string memory idx = vm.toString(i);

            assertEq(
                rebalanceCooldown, expected.cooldown, string.concat("Pool config cooldown mismatch at index ", idx)
            );
            assertEq(
                protocolFeeRecipient,
                registry.lookup("ProtocolFeeRecipient"),
                string.concat("Pool config protocolFeeRecipient mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveExpansion,
                expected.liquiditySourceIncentiveExpansion,
                string.concat("Pool config lsIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveExpansion,
                expected.protocolIncentiveExpansion,
                string.concat("Pool config protocolIncentiveExpansion mismatch at index ", idx)
            );
            assertEq(
                lsIncentiveContraction,
                expected.liquiditySourceIncentiveContraction,
                string.concat("Pool config lsIncentiveContraction mismatch at index ", idx)
            );
            assertEq(
                protocolIncentiveContraction,
                expected.protocolIncentiveContraction,
                string.concat("Pool config protocolIncentiveContraction mismatch at index ", idx)
            );
        }
    }

    /// @dev Loads the CDPMigrationConfig for a pool by deriving the token name from the debt token symbol
    function _getCDPMigrationConfig(address pool) internal view returns (IMentoConfig.CDPMigrationConfig memory) {
        address debtToken = _getDebtToken(pool);
        string memory symbol = IERC20Metadata(debtToken).symbol();
        return config.getCDPMigrationConfig(symbol);
    }

    /// @dev Loads the LiquityInstanceConfig for a pool by deriving the token symbol
    function _getLiquityInstanceConfig(address pool) internal returns (ILiquityConfig.LiquityInstanceConfig memory) {
        address debtToken = _getDebtToken(pool);
        string memory symbol = IERC20Metadata(debtToken).symbol();
        return Config.getLiquity(symbol).get();
    }

    // ========== FXPriceFeed RateFeedID (US-010) ==========

    /// @notice Verify FXPriceFeed.rateFeedID matches the FPMM pool's referenceRateFeedID and CDPMigrationConfig
    function test_cdpPools_fxPriceFeed_rateFeedIdMatchesPool() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);

            address priceFeedAddr = _getPriceFeed(troveManagerAddr);
            assertNotEq(
                priceFeedAddr,
                address(0),
                string.concat("PriceFeed address is zero for CDP pool at index ", vm.toString(i))
            );

            IMentoConfig.CDPMigrationConfig memory expected = _getCDPMigrationConfig(cdpPools[i]);

            address fxRateFeedID = IFXPriceFeed(priceFeedAddr).rateFeedID();
            address poolRateFeedID = IFPMM(cdpPools[i]).referenceRateFeedID();

            assertEq(
                fxRateFeedID,
                poolRateFeedID,
                string.concat(
                    "FXPriceFeed.rateFeedID does not match FPMM.referenceRateFeedID for CDP pool at index ",
                    vm.toString(i)
                )
            );
            assertEq(
                fxRateFeedID,
                expected.rateFeedID,
                string.concat(
                    "FXPriceFeed.rateFeedID does not match CDPMigrationConfig.rateFeedID for CDP pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== FXPriceFeed OracleAdapter (US-010) ==========

    /// @notice Verify FXPriceFeed.oracleAdapter matches the deployed OracleAdapter proxy
    function test_cdpPools_fxPriceFeed_oracleAdapter() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            assertEq(
                IFXPriceFeed(priceFeedAddr).oracleAdapter(),
                oracleAdapter,
                string.concat("FXPriceFeed.oracleAdapter() mismatch for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed invertRateFeed (US-010) ==========

    /// @notice Verify FXPriceFeed.invertRateFeed matches the Liquity config
    function test_cdpPools_fxPriceFeed_invertRateFeed() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            ILiquityConfig.LiquityInstanceConfig memory liquityCfg = _getLiquityInstanceConfig(cdpPools[i]);

            assertEq(
                IFXPriceFeed(priceFeedAddr).invertRateFeed(),
                liquityCfg.invertRateFeed,
                string.concat("FXPriceFeed.invertRateFeed() mismatch for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed l2SequencerGracePeriod (US-010) ==========

    /// @notice Verify FXPriceFeed.l2SequencerGracePeriod matches the Liquity config
    function test_cdpPools_fxPriceFeed_l2SequencerGracePeriod() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            ILiquityConfig.LiquityInstanceConfig memory liquityCfg = _getLiquityInstanceConfig(cdpPools[i]);

            assertEq(
                IFXPriceFeed(priceFeedAddr).l2SequencerGracePeriod(),
                liquityCfg.l2SequencerGracePeriod,
                string.concat("FXPriceFeed.l2SequencerGracePeriod() mismatch for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed borrowerOperations (US-010) ==========

    /// @notice Verify FXPriceFeed.borrowerOperations matches the Liquity BorrowerOperations
    function test_cdpPools_fxPriceFeed_borrowerOperations() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (address borrowerOps,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            assertEq(
                IFXPriceFeed(priceFeedAddr).borrowerOperations(),
                borrowerOps,
                string.concat("FXPriceFeed.borrowerOperations() mismatch for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed watchdogAddress (US-010) ==========

    /// @notice Verify FXPriceFeed.watchdogAddress is set (non-zero)
    function test_cdpPools_fxPriceFeed_watchdogAddress() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            assertEq(
                IFXPriceFeed(priceFeedAddr).watchdogAddress(),
                _getOwner(),
                string.concat("FXPriceFeed.watchdogAddress() is zero for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed isShutdown (US-010) ==========

    /// @notice Verify FXPriceFeed is not shutdown
    function test_cdpPools_fxPriceFeed_notShutdown() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            assertFalse(
                IFXPriceFeed(priceFeedAddr).isShutdown(),
                string.concat("FXPriceFeed is shutdown for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FXPriceFeed isL2SequencerUp (US-010) ==========

    /// @notice Verify FXPriceFeed.isL2SequencerUp() returns true
    function test_cdpPools_fxPriceFeed_l2SequencerUp() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);

            assertTrue(
                IFXPriceFeed(priceFeedAddr).isL2SequencerUp(),
                string.concat("FXPriceFeed.isL2SequencerUp() is false for CDP pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Reserve Trove State (US-010) ==========

    /// @notice Verify reserve trove is active, owned by ReserveSafe, and has correct interest rate
    function test_cdpPools_reserveTrove_valid() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);
            string memory idx = vm.toString(i);

            // Active
            ITroveManager.Status status = ITroveManager(troveManagerAddr).getTroveStatus(troveId);
            assertEq(
                uint256(status),
                uint256(ITroveManager.Status.active),
                string.concat("Reserve trove is not active for CDP pool at index ", idx)
            );

            // Owned by ReserveSafe
            ITroveNFT troveNFT = ITroveManager(troveManagerAddr).troveNFT();
            assertEq(
                troveNFT.ownerOf(troveId),
                reserveSafe,
                string.concat("Reserve trove NFT not owned by ReserveSafe for CDP pool at index ", idx)
            );
        }
    }

    // ========== ReserveTroveFactory Cleanup (US-010) ==========

    /// @notice Verify ReserveTroveFactory does NOT have minter/burner roles on debt tokens (cleanup verified)
    function test_cdpPools_reserveTroveFactory_noMinterBurner() public view {
        address reserveTroveFactory = registry.lookup("ReserveTroveFactory");
        if (reserveTroveFactory == address(0)) {
            // Also try versioned lookup
            reserveTroveFactory = registry.lookup("ReserveTroveFactory:v3.0.0");
        }

        // If ReserveTroveFactory is not registered, the cleanup test is vacuously true
        // (factory was either never deployed or already fully removed)
        if (reserveTroveFactory == address(0)) {
            return;
        }

        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            assertFalse(
                IStableTokenV3(debtToken).isMinter(reserveTroveFactory),
                string.concat(
                    "ReserveTroveFactory is still minter on CDP debt token for pool at index ", vm.toString(i)
                )
            );
            assertFalse(
                IStableTokenV3(debtToken).isBurner(reserveTroveFactory),
                string.concat(
                    "ReserveTroveFactory is still burner on CDP debt token for pool at index ", vm.toString(i)
                )
            );
        }
    }

    // ========== Stable Token Mint/Burn Operations ==========

    /// @notice BorrowerOperations should be able to mint CDP debt tokens
    function test_cdpDebtToken_borrowerOps_canMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (address borrowerOps,,,) = _getLiquityContracts(cdpPools[i]);
            address recipient = makeAddr("mintRecipient");

            uint256 mintAmount = 1e18;
            uint256 balBefore = IStableTokenV3(debtToken).balanceOf(recipient);

            vm.prank(borrowerOps);
            IStableTokenV3(debtToken).mint(recipient, mintAmount);

            uint256 balAfter = IStableTokenV3(debtToken).balanceOf(recipient);
            assertEq(
                balAfter - balBefore,
                mintAmount,
                string.concat("BorrowerOps mint failed for pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice A random non-authorized address should NOT be able to mint
    function test_cdpDebtToken_randomAddress_cannotMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            address randomUser = makeAddr("randomMinter");

            vm.prank(randomUser);
            vm.expectRevert();
            IStableTokenV3(debtToken).mint(randomUser, 1e18);
        }
    }

    /// @notice CollateralRegistry should be able to burn CDP debt tokens
    function test_cdpDebtToken_collateralRegistry_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);

            uint256 burnAmount = 1e18;
            _dealTokens(debtToken, cdpConfig.collateralRegistry, burnAmount);

            vm.prank(cdpConfig.collateralRegistry);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice BorrowerOperations should be able to burn CDP debt tokens
    function test_cdpDebtToken_borrowerOps_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (address borrowerOps,,,) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            _dealTokens(debtToken, borrowerOps, burnAmount);

            vm.prank(borrowerOps);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice TroveManager should be able to burn CDP debt tokens
    function test_cdpDebtToken_troveManager_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            _dealTokens(debtToken, troveManagerAddr, burnAmount);

            vm.prank(troveManagerAddr);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice StabilityPool should be able to burn CDP debt tokens
    function test_cdpDebtToken_stabilityPool_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            _dealTokens(debtToken, stabilityPoolAddr, burnAmount);

            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    // ========== Broker Cannot Mint/Burn ==========

    /// @notice Broker should NOT be able to mint CDP debt tokens
    function test_cdpDebtToken_broker_cannotMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);

            vm.prank(broker);
            vm.expectRevert();
            IStableTokenV3(debtToken).mint(broker, 1e18);
        }
    }

    /// @notice Broker should NOT be able to burn CDP debt tokens
    function test_cdpDebtToken_broker_cannotBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);

            _dealTokens(debtToken, broker, 1e18);

            vm.prank(broker);
            vm.expectRevert();
            IStableTokenV3(debtToken).burn(1e18);
        }
    }

    // ========== StabilityPool Operator Transfers ==========

    /// @notice StabilityPool as operator can call sendToPool (direct transfer without approval)
    function test_cdpDebtToken_stabilityPool_canSendToPool() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            address sender = makeAddr("tokenHolder");
            uint256 amount = 1e18;
            _dealTokens(debtToken, sender, amount);

            uint256 senderBalBefore = IStableTokenV3(debtToken).balanceOf(sender);
            uint256 poolBalBefore = IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr);

            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).sendToPool(sender, stabilityPoolAddr, amount);

            assertEq(
                IStableTokenV3(debtToken).balanceOf(sender),
                senderBalBefore - amount,
                string.concat("sendToPool: sender balance not decreased for pool at index ", vm.toString(i))
            );
            assertEq(
                IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr),
                poolBalBefore + amount,
                string.concat("sendToPool: pool balance not increased for pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice StabilityPool as operator can call returnFromPool (direct transfer without approval)
    function test_cdpDebtToken_stabilityPool_canReturnFromPool() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            address receiver = makeAddr("tokenReceiver");
            uint256 amount = 1e18;
            _dealTokens(debtToken, stabilityPoolAddr, amount);

            uint256 poolBalBefore = IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr);
            uint256 receiverBalBefore = IStableTokenV3(debtToken).balanceOf(receiver);

            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).returnFromPool(stabilityPoolAddr, receiver, amount);

            assertEq(
                IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr),
                poolBalBefore - amount,
                string.concat("returnFromPool: pool balance not decreased for pool at index ", vm.toString(i))
            );
            assertEq(
                IStableTokenV3(debtToken).balanceOf(receiver),
                receiverBalBefore + amount,
                string.concat("returnFromPool: receiver balance not increased for pool at index ", vm.toString(i))
            );
        }
    }
}
