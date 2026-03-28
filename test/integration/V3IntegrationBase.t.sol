// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {
    BokkyPooBahsDateTimeLibrary as DateTimeLib
} from "lib/mento-core/lib/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
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
import {OracleHelper} from "script/helpers/OracleHelper.sol";

import {MockCELO} from "script/helpers/MockCELO.sol";

import {console2 as console} from "forge-std/console2.sol";

/// @dev Read the auto-generated poolConfigs getter from LiquidityStrategy
interface IPoolConfigReader {
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
    address internal deployerAccount = 0x2738F38Fde510743e0c589415E0598C4ceE6eAa7;
    address internal sortedOracles;
    address internal proxyAdmin;
    address internal marketHoursBreaker;
    address internal l2SequencerUptimeFeed;
    address internal broker;
    address internal reserveSafe;
    address internal oracleAdapterCollateral;
    uint256 internal timestamp_weekend;
    uint256 internal timestamp_weekday;

    modifier onlyCelo() {
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        _;
    }

    function setUp() public virtual {
        // Fork chain
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);

        // Compute future weekday/weekend timestamps dynamically from the fork's block.timestamp
        timestamp_weekday = _nextFXWeekday(block.timestamp);
        timestamp_weekend = _nextFXWeekend(block.timestamp);

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
        if (_isCelo()) {
            vm.etch(lookupOrFail("CELO"), type(MockCELO).runtimeCode);
            virtualPoolFactory = lookupOrFail("VirtualPoolFactory:v3.0.0");
            cdpLiquidityStrategy = lookupProxyOrFail("CDPLiquidityStrategy");
            broker = lookupProxyOrFail("Broker");
        }

        // Resolve key V3 addresses from registry
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
        factoryRegistry = lookupProxyOrFail("FactoryRegistry");
        router = lookupOrFail("Router:v3.0.0");
        reserveV2 = lookupProxyOrFail("ReserveV2");
        reserveLiquidityStrategy = lookupProxyOrFail("ReserveLiquidityStrategy");
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        sortedOracles = lookupProxyOrFail("SortedOracles");
        proxyAdmin = lookupOrFail("ProxyAdmin");
        marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        l2SequencerUptimeFeed = registry.lookup("L2SequencerUptimeFeed");
        reserveSafe = lookupOrFail("ReserveSafe");
        oracleAdapterCollateral = registry.lookup("TransparentUpgradeableProxy:OracleAdapterCollateral");

        // Warp to a weekday so FX markets are open. Tests that need a specific time
        // (e.g. WeekendSituationTest) warp to their target inside each test function.
        vm.warp(timestamp_weekday);
        OracleHelper.refreshOracleRates(sortedOracles, config);
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

    // ========== Timestamp Helpers ==========

    /// @dev Returns a future timestamp on the next Tuesday at 12:00 UTC (clearly within FX trading hours).
    ///      MarketHoursBreaker defines FX weekend as: Friday >= 21:00, Saturday, Sunday < 23:00.
    function _nextFXWeekday(uint256 from) internal pure returns (uint256) {
        uint256 dow = DateTimeLib.getDayOfWeek(from);
        // Target: Tuesday (dow=2), at 12:00 UTC
        uint256 daysUntilTuesday = (2 + 7 - dow) % 7;
        if (daysUntilTuesday == 0) daysUntilTuesday = 7;
        uint256 dayStart = (from / 86400 + daysUntilTuesday) * 86400;
        return dayStart + 12 hours;
    }

    /// @dev Returns a future timestamp on the next Saturday at 12:00 UTC (clearly within FX weekend hours).
    function _nextFXWeekend(uint256 from) internal pure returns (uint256) {
        uint256 dow = DateTimeLib.getDayOfWeek(from);
        // Target: Saturday (dow=6), at 12:00 UTC
        uint256 daysUntilSaturday = (6 + 7 - dow) % 7;
        if (daysUntilSaturday == 0) daysUntilSaturday = 7;
        uint256 dayStart = (from / 86400 + daysUntilSaturday) * 86400;
        return dayStart + 12 hours;
    }

    // ========== Test Helpers ==========

    function _getOwner() internal view returns (address) {
        return lookupOrFail("MigrationMultisig");
    }

    // ========== Shared CDP Helpers ==========

    /// @dev Returns the debt token for a CDP pool based on the isToken0Debt flag
    function _getDebtToken(address pool) internal view returns (address) {
        (bool isToken0Debt,,,,,,,) = IPoolConfigReader(cdpLiquidityStrategy).poolConfigs(pool);
        return isToken0Debt ? IFPMM(pool).token0() : IFPMM(pool).token1();
    }

    /// @dev Derives Liquity contract addresses from the CDPConfig via contract chaining
    ///      Returns (borrowerOperations, activePool, troveManager, stabilityPool)
    function _getLiquityContracts(address pool)
        internal
        view
        returns (address borrowerOps, address activePoolAddr, address troveManagerAddr, address stabilityPoolAddr)
    {
        ICDPLiquidityStrategy.CDPConfig memory
            cdpConfig = ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(pool);

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
        uint256 reserveOut = sellToken0 ? r1 : r0;
        // Cap amountIn so the output never exceeds the output reserve.
        // Use getAmountOut to convert a fraction of reserveOut into the input denomination.
        uint256 amountIn = reserveIn / 10;
        if (amountIn > 0) {
            uint256 estOut = fpmm.getAmountOut(amountIn, tokenIn);
            // If estimated output would consume >= 50% of output reserve, reduce amountIn
            while (estOut >= reserveOut / 2 && amountIn > 1) {
                amountIn = amountIn / 2;
                estOut = fpmm.getAmountOut(amountIn, tokenIn);
            }
        }
        require(amountIn > 0, "Reserve too low for imbalance swap");

        uint256 expectedOut = fpmm.getAmountOut(amountIn, tokenIn);
        require(expectedOut > 0, "getAmountOut returned zero for imbalance swap");

        _dealTokens(tokenIn, trader, amountIn);
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
        for (uint256 i = 0; i < 10; i++) {
            _imbalancePool(pool, trader, sellToken0);
            (,,,,, uint16 threshold, uint256 priceDiff) = IFPMM(pool).getRebalancingState();
            if (priceDiff > uint256(threshold)) return;
            // Warp past the L0 trading limit window so the next swap doesn't accumulate
            vm.warp(block.timestamp + 5 minutes + 1);
            _refreshOracleRates();
        }
        revert("Failed to imbalance pool after 10 attempts");
    }

    // ========== Pool Liquidity Helpers ==========

    /// @dev Ensures a pool has at least 100 units of each token so swap/liquidity tests don't
    ///      fail due to drained on-chain state. Deals tokens and mints LP if either reserve is low.
    ///      Amounts are added proportionally to existing reserves so mint() yields LP > 0.
    function _ensurePoolLiquidity(address pool) internal {
        IFPMM fpmm = IFPMM(pool);
        (uint256 r0, uint256 r1,) = fpmm.getReserves();
        IERC20Metadata t0 = IERC20Metadata(fpmm.token0());
        IERC20Metadata t1 = IERC20Metadata(fpmm.token1());
        uint256 min0 = 100 * (10 ** t0.decimals());
        uint256 min1 = 100 * (10 ** t1.decimals());
        if (r0 >= min0 && r1 >= min1) return;

        // Base amounts needed to reach minimums
        uint256 add0 = r0 < min0 ? min0 - r0 : 0;
        uint256 add1 = r1 < min1 ? min1 - r1 : 0;

        // FPMM mint() computes LP = min(add0*supply/r0, add1*supply/r1).
        // If adds are not proportional to reserves, the min collapses to ~0 and minting reverts.
        // Enforce proportionality by scaling up the side that would otherwise be too small.
        if (r0 > 0 && r1 > 0) {
            uint256 add0Prop = add1 > 0 ? (add1 * r0 + r1 - 1) / r1 : 0;
            uint256 add1Prop = add0 > 0 ? (add0 * r1 + r0 - 1) / r0 : 0;
            if (add0Prop > add0) add0 = add0Prop;
            if (add1Prop > add1) add1 = add1Prop;
        }

        if (add0 == 0 && add1 == 0) return;
        if (add0 == 0) add0 = 1;
        if (add1 == 0) add1 = 1;

        _dealTokens(address(t0), address(this), add0);
        _dealTokens(address(t1), address(this), add1);
        IERC20(address(t0)).transfer(pool, add0);
        IERC20(address(t1)).transfer(pool, add1);
        fpmm.mint(address(this));
    }

    // ========== Oracle Refresh Helpers ==========

    /// @dev Re-reports current oracle rates so they remain fresh after time jumps.
    function _refreshOracleRates() internal {
        OracleHelper.refreshOracleRates(sortedOracles, config);
    }

    // ========== Internal ==========

    function _isCelo() internal view returns (bool) {
        return block.chainid == 42220 || block.chainid == 11142220;
    }

    /// @dev Sets a dummy SENDER_CONFIGS env var so that MentoConfig (which inherits TrebScript)
    ///      can be instantiated in a test context. The config is never used for sending transactions.
    function _setDummySenderConfigs() internal {
        Senders.SenderInitConfig[] memory configs = new Senders.SenderInitConfig[](1);

        // We need the deployer's address here because in one test we check aggregator addresses
        // for each relayer, if we put a dummy address here, it affects relayer configured using
        // the _predict() function.
        configs[0] = Senders.SenderInitConfig({
            name: "deployer",
            account: deployerAccount,
            senderType: SenderTypes.InMemory,
            canBroadcast: false,
            config: abi.encode(uint256(1))
        });
        vm.setEnv("SENDER_CONFIGS", vm.toString(abi.encode(configs)));
    }

    /// @dev Tries mint() → foundry deal() → AUSD manual storage write, in that order.
    function _dealTokens(address token, address to, uint256 amount) internal {
        // 1. Try mint(to, amount)
        uint256 balanceBefore = IERC20(token).balanceOf(to);
        try MockCELO(token).mint(to, amount) {
            if (IERC20(token).balanceOf(to) == amount + balanceBefore) return;
        } catch {}

        // 2. Try foundry's deal() which uses stdstore to find the balanceOf slot
        try this._tryDeal(token, to, amount) {
            if (IERC20(token).balanceOf(to) == amount) return;
        } catch {}

        // 3. Fall back to AUSD-specific ERC-7201 storage write
        _dealAUSD(token, to, amount);
    }

    /// @dev Wrapper so we can try/catch foundry's deal().
    function _tryDeal(address token, address to, uint256 amount) external {
        deal(token, to, amount);
    }

    /// @dev Writes directly to AUSD's ERC-7201 storage to set a balance.
    ///
    /// AUSD uses ERC-7201 namespaced storage. The Erc20CoreStorage struct lives at:
    ///   slot = keccak256(abi.encode(uint256(keccak256("AgoraDollarErc1967Proxy.Erc20CoreStorage")) - 1)) & ~bytes32(uint256(0xff))
    ///        = 0x455730fed596673e69db1907be2e521374ba893f1a04cc5f5dd931616cd6b700
    ///
    /// The first field is `mapping(address => Erc20AccountData) accountData` so the
    /// mapping base slot equals the struct slot. For a given account the data lives at:
    ///   keccak256(abi.encode(account, base_slot))
    ///
    /// Erc20AccountData is { bool isFrozen; uint248 balance } packed into one word:
    ///   - bit 0      : isFrozen
    ///   - bits 8-255 : balance  (uint248, shifted left by 8 bits)
    function _dealAUSD(address ausd, address to, uint256 amount) internal {
        bytes32 baseSlot = 0x455730fed596673e69db1907be2e521374ba893f1a04cc5f5dd931616cd6b700;
        bytes32 accountSlot = keccak256(abi.encode(to, baseSlot));
        // Preserve the isFrozen flag (lowest byte), write balance into upper 248 bits.
        bytes32 current = vm.load(ausd, accountSlot);
        bytes32 newVal = bytes32((amount << 8) | (uint256(current) & 0xff));
        vm.store(ausd, accountSlot, newVal);
    }
}
