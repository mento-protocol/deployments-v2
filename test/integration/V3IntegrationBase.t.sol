// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {Config, IMentoConfig} from "script/config/Config.sol";
import {ICeloProxy} from "mento-core/interfaces/ICeloProxy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {ITroveNFT} from "bold/src/Interfaces/ITroveNFT.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IActivePool} from "bold/src/Interfaces/IActivePool.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev Read the auto-generated poolConfigs getter from LiquidityStrategy
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
 * @title V3IntegrationBase
 * @notice Base abstract contract for V3 integration tests.
 * @dev Forks a chain via FORK_URL env var and resolves key V3 contract addresses
 *      from the Treb registry (.treb/registry.json and .treb/addressbook.json).
 *
 *      Provides lookupOrFail/lookupProxyOrFail helpers matching the ProxyHelper API,
 *      and proxy introspection utilities (getProxyImplementation, getProxyAdmin).
 *
 *      Environment variables:
 *      - FORK_URL (required): RPC URL to fork
 *      - NETWORK (required): Network name for config resolution (e.g., "celo_sepolia")
 *      - NAMESPACE (optional): Treb registry namespace (default: "default")
 */
abstract contract V3IntegrationBase is Test {
    // ========== Registry & Config ==========
    Registry internal registry;
    IMentoConfig internal config;
    uint256 internal forkId;

    // ========== Key V3 Contract Addresses ==========
    address internal fpmmFactory;
    address internal oracleAdapter;
    address internal factoryRegistry;
    address internal virtualPoolFactory;
    address internal router;
    address internal reserveV2;
    address internal reserveLiquidityStrategy;
    address internal cdpLiquidityStrategy;
    address internal breakerBox;
    address internal sortedOracles;
    address internal proxyAdmin;
    address internal marketHoursBreaker;
    address internal broker;
    address internal reserveSafe;

    function setUp() public virtual {
        // Fork chain
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);

        // Create registry for address lookups (must be after fork so block.chainid is correct)
        string memory namespace = vm.envOr("NAMESPACE", string("default"));
        registry = new Registry(namespace, ".treb/registry.json", ".treb/addressbook.json");

        // Load config
        config = Config.get();

        // Resolve key V3 addresses from registry
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
        factoryRegistry = lookupProxyOrFail("FactoryRegistry");
        virtualPoolFactory = lookupOrFail("VirtualPoolFactory:v3.0.0");
        router = lookupOrFail("Router:v3.0.0");
        reserveV2 = lookupProxyOrFail("ReserveV2");
        reserveLiquidityStrategy = lookupProxyOrFail("ReserveLiquidityStrategy");
        cdpLiquidityStrategy = lookupProxyOrFail("CDPLiquidityStrategy");
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        sortedOracles = lookupProxyOrFail("SortedOracles");
        proxyAdmin = lookupOrFail("ProxyAdmin");
        marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        broker = lookupProxyOrFail("Broker");
        reserveSafe = lookupOrFail("ReserveSafe");
    }

    // ========== Registry Lookup Helpers ==========

    function lookupOrFail(string memory identifier) internal view returns (address addy) {
        addy = registry.lookup(identifier);
        require(addy != address(0), string.concat(identifier, " not deployed"));
    }

    function lookupProxyOrFail(string memory contractName) internal view returns (address proxy) {
        address celo = registry.lookup(string.concat("Proxy:", contractName));
        address oztup = registry.lookup(string.concat("TransparentUpgradeableProxy:", contractName));
        require(
            celo == address(0) || oztup == address(0),
            string.concat(contractName, " found as both Celo and OZTUP proxy, be explicit")
        );
        proxy = celo != address(0) ? celo : oztup;
        require(proxy != address(0), string.concat(contractName, " proxy not deployed"));
    }

    // ========== Proxy Helpers ==========

    function getProxyImplementation(address proxy) internal view returns (address) {
        try ICeloProxy(proxy)._getImplementation() returns (address impl) {
            if (impl != address(0)) {
                return impl;
            }
        } catch {}

        // Fall back to EIP-1967 implementation slot (OZTUP)
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxy, implSlot))));
    }

    function getProxyAdmin(address proxy) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(proxy, 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)
                    )
                )
            );
    }

    // ========== Test Helpers ==========

    function _mintToken(address token, address to, uint256 amount) internal {
        deal(token, to, amount);
    }

    function _getOwner() internal view returns (address) {
        return lookupOrFail("MigrationMultisig");
    }

    // ========== Shared CDP Helpers ==========

    /// @dev Returns the debt token for a CDP pool based on the isToken0Debt flag
    function _getDebtToken(address pool) internal view returns (address) {
        (bool isToken0Debt,,,,,,, ) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);
        return isToken0Debt ? IFPMM(pool).token0() : IFPMM(pool).token1();
    }

    /// @dev Derives Liquity contract addresses from the CDPConfig via contract chaining
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

    /// @dev Finds the reserve trove ID by iterating all troves and finding the one owned by ReserveSafe
    function _findReserveTrove(address troveManagerAddr) internal view returns (uint256) {
        ITroveManager tm = ITroveManager(troveManagerAddr);
        ITroveNFT troveNFT = tm.troveNFT();
        uint256 troveCount = tm.getTroveIdsCount();

        for (uint256 i = 0; i < troveCount; i++) {
            uint256 troveId = tm.getTroveFromTroveIdsArray(i);
            if (troveNFT.ownerOf(troveId) == reserveSafe) {
                return troveId;
            }
        }

        revert("Reserve trove not found");
    }

    /// @dev Read priceFeed from TroveManager storage.
    /// LiquityBase (non-upgradeable) layout: slot0=activePool, slot1=defaultPool, slot2=priceFeed
    function _getPriceFeed(address troveManagerAddr) internal view returns (address) {
        return address(uint160(uint256(vm.load(troveManagerAddr, bytes32(uint256(2))))));
    }
}
