// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {Config, IMentoConfig} from "script/config/Config.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {ProxyViewHelper} from "script/helpers/ProxyViewHelper.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {ITroveNFT} from "bold/src/Interfaces/ITroveNFT.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IActivePool} from "bold/src/Interfaces/IActivePool.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";

import {console2 as console} from "forge-std/console2.sol";

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
abstract contract V3IntegrationBase is Test, ProxyViewHelper {
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

        // Load config.
        // MentoConfig inherits TrebScript which requires SENDER_CONFIGS env var.
        // In test context we provide a minimal dummy config so the constructor succeeds,
        // then re-select our fork since TrebScript's SenderCoordinator creates its own forks.
        _setDummySenderConfigs();
        config = Config.get();
        vm.selectFork(forkId);

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
        // marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        marketHoursBreaker = lookupOrFail("MarketHoursBreakerToggleable:v3.0.0");
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

    /// @dev Resolves the Liquity AddressesRegistry for a CDP pool via its debt token symbol
    function _getAddressesRegistry(address pool) internal view returns (IAddressesRegistry) {
        address debtToken = _getDebtToken(pool);
        string memory symbol = IERC20Metadata(debtToken).symbol();
        string memory registryKey = string.concat("AddressesRegistry:v3.0.0-", symbol);
        address addr = registry.lookup(registryKey);
        require(addr != address(0), string.concat(registryKey, " not found in registry"));
        return IAddressesRegistry(addr);
    }

    // ========== Shared Rebalance Helpers ==========

    /// @dev Does a large one-sided swap to imbalance an FPMM pool
    function _imbalancePool(address pool, address trader, bool sellToken0) internal {
        IFPMM fpmm = IFPMM(pool);
        address tokenIn = sellToken0 ? fpmm.token0() : fpmm.token1();

        (uint256 r0, uint256 r1,) = fpmm.getReserves();
        uint256 reserveIn = sellToken0 ? r0 : r1;
        uint256 amountIn = reserveIn / 10;
        require(amountIn > 0, "Reserve too low for imbalance swap");

        uint256 expectedOut = fpmm.getAmountOut(amountIn, tokenIn);
        require(expectedOut > 0, "getAmountOut returned zero for imbalance swap");

        deal(tokenIn, trader, amountIn);
        vm.startPrank(trader);
        IERC20(tokenIn).transfer(address(fpmm), amountIn);
        if (sellToken0) {
            fpmm.swap(0, expectedOut, trader, "");
        } else {
            fpmm.swap(expectedOut, 0, trader, "");
        }
        vm.stopPrank();
    }

    /// @dev Ensures the pool is imbalanced past its rebalancing threshold
    function _ensureImbalanced(address pool, address trader, bool sellToken0) internal {
        _imbalancePool(pool, trader, sellToken0);
        (,,,,, uint16 threshold, uint256 priceDiff) = IFPMM(pool).getRebalancingState();
        if (priceDiff <= uint256(threshold)) {
            _imbalancePool(pool, trader, sellToken0);
        }
    }

    // ========== Oracle Refresh Helpers ==========

    /// @dev Re-reports current oracle rates for all deployed FPMM pools so that
    ///      rates remain fresh after time jumps (vm.warp / skip).
    function _refreshOracleRates() internal {
        ISortedOracles so = ISortedOracles(sortedOracles);
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();

        for (uint256 i = 0; i < pools.length; i++) {
            address rateFeedID = IFPMM(pools[i]).referenceRateFeedID();
            (uint256 rate, ) = so.medianRate(rateFeedID);
            if (rate == 0) continue;

            address[] memory oracles = so.getOracles(rateFeedID);
            if (oracles.length == 0) continue;

            vm.prank(oracles[0]);
            so.report(rateFeedID, rate, address(0), address(0));
        }
    }

    // ========== Internal ==========

    /// @dev Sets a dummy SENDER_CONFIGS env var so that MentoConfig (which inherits TrebScript)
    ///      can be instantiated in a test context. The config is never used for sending transactions.
    function _setDummySenderConfigs() internal {
        Senders.SenderInitConfig[] memory configs = new Senders.SenderInitConfig[](1);
        configs[0] = Senders.SenderInitConfig({
            name: "deployer",
            account: address(1),
            senderType: SenderTypes.InMemory,
            canBroadcast: false,
            config: abi.encode(uint256(1))
        });
        vm.setEnv("SENDER_CONFIGS", vm.toString(abi.encode(configs)));
    }
}
