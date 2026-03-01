// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {ILiquidityStrategy} from "mento-core/interfaces/ILiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {ICollateralRegistry} from "bold/src/Interfaces/ICollateralRegistry.sol";
import {IActivePool} from "bold/src/Interfaces/IActivePool.sol";

/// @dev Minimal interface to read the auto-generated poolConfigs getter from LiquidityStrategy
interface IPoolConfigReader {
    function poolConfigs(address pool) external view returns (
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
 * @title CDPMigrationVerification
 * @notice Verifies CDP migration state: roles, strategy config, V2 exchange cleanup,
 *         and Liquity contract role assignments on CDP-migrated tokens.
 */
contract CDPMigrationVerification is V3IntegrationBase {
    address[] internal cdpPools;
    address internal biPoolManager;

    function setUp() public override {
        super.setUp();
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
                string.concat(
                    "V2 BiPoolManager exchange still exists for CDP pool at index ",
                    vm.toString(i)
                )
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
                string.concat(
                    "CDPLiquidityStrategy not enabled on FPMM pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

    /// @notice Verify each CDP pool is registered on CDPLiquidityStrategy
    function test_cdpPools_registeredOnStrategy() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            assertTrue(
                ICDPLiquidityStrategy(cdpLiquidityStrategy).isPoolRegistered(cdpPools[i]),
                string.concat(
                    "CDP pool not registered on CDPLiquidityStrategy at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== CDPConfig Values Valid ==========

    /// @notice Verify CDPConfig has valid non-zero values and stabilityPool/collateralRegistry are consistent
    function test_cdpPools_cdpConfig_valid() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);

            assertNotEq(
                cdpConfig.stabilityPool,
                address(0),
                string.concat("CDPConfig stabilityPool is zero for pool at index ", vm.toString(i))
            );
            assertNotEq(
                cdpConfig.collateralRegistry,
                address(0),
                string.concat("CDPConfig collateralRegistry is zero for pool at index ", vm.toString(i))
            );
            assertGt(
                cdpConfig.stabilityPoolPercentage,
                0,
                string.concat("CDPConfig stabilityPoolPercentage is zero for pool at index ", vm.toString(i))
            );
            assertLt(
                cdpConfig.stabilityPoolPercentage,
                10000,
                string.concat("CDPConfig stabilityPoolPercentage >= 10000 for pool at index ", vm.toString(i))
            );
            assertGt(
                cdpConfig.maxIterations,
                0,
                string.concat("CDPConfig maxIterations is zero for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Pool Config (Cooldown, Incentives, ProtocolFeeRecipient) Valid ==========

    /// @notice Verify pool config has valid non-zero cooldown, protocolFeeRecipient, and incentive values
    function test_cdpPools_poolConfig_valid() public view {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            (
                ,
                ,
                uint32 rebalanceCooldown,
                address protocolFeeRecipient,
                uint64 lsIncentiveExpansion,
                uint64 protocolIncentiveExpansion,
                uint64 lsIncentiveContraction,
                uint64 protocolIncentiveContraction
            ) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(cdpPools[i]);

            assertGt(
                rebalanceCooldown,
                0,
                string.concat("Pool config rebalanceCooldown is zero for pool at index ", vm.toString(i))
            );
            assertNotEq(
                protocolFeeRecipient,
                address(0),
                string.concat("Pool config protocolFeeRecipient is zero for pool at index ", vm.toString(i))
            );
            assertGt(
                lsIncentiveExpansion,
                0,
                string.concat(
                    "Pool config liquiditySourceIncentiveExpansion is zero for pool at index ",
                    vm.toString(i)
                )
            );
            assertGt(
                protocolIncentiveExpansion,
                0,
                string.concat("Pool config protocolIncentiveExpansion is zero for pool at index ", vm.toString(i))
            );
            assertGt(
                lsIncentiveContraction,
                0,
                string.concat(
                    "Pool config liquiditySourceIncentiveContraction is zero for pool at index ",
                    vm.toString(i)
                )
            );
            assertGt(
                protocolIncentiveContraction,
                0,
                string.concat(
                    "Pool config protocolIncentiveContraction is zero for pool at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ========== Internal Helpers ==========

    /// @dev Returns the debt token for a CDP pool based on the isToken0Debt flag
    function _getDebtToken(address pool) internal view returns (address) {
        (bool isToken0Debt,,,,,,, ) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);
        return isToken0Debt ? IFPMM(pool).token0() : IFPMM(pool).token1();
    }

    /// @dev Derives Liquity contract addresses from the CDPConfig
    ///      Returns (borrowerOperations, activePool, troveManager, stabilityPool)
    function _getLiquityContracts(address pool)
        internal
        view
        returns (address borrowerOps, address activePoolAddr, address troveManagerAddr, address stabilityPoolAddr)
    {
        ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
            ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(pool);

        stabilityPoolAddr = cdpConfig.stabilityPool;

        // StabilityPool → TroveManager → BorrowerOperations → ActivePool
        ITroveManager tm = IStabilityPool(stabilityPoolAddr).troveManager();
        troveManagerAddr = address(tm);

        IBorrowerOperations bo = tm.borrowerOperations();
        borrowerOps = address(bo);

        IActivePool ap = bo.activePool();
        activePoolAddr = address(ap);
    }
}
