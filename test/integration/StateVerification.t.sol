// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";
import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IVirtualPoolFactory} from "mento-core/interfaces/IVirtualPoolFactory.sol";
import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IRPool} from "mento-core/swap/router/interfaces/IRPool.sol";
import {IRPoolFactory} from "mento-core/swap/router/interfaces/IRPoolFactory.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {console2 as console} from "forge-std/console2.sol";

/**
 * @title StateVerification
 * @notice Verifies proxy implementations, init protection, ProxyAdmin config, ownership,
 *         and oracle/breaker configuration for V3 contracts.
 */
contract StateVerification is V3IntegrationBase {
    // Implementation addresses resolved in setUp
    address internal oracleAdapterImpl;
    address internal fpmmFactoryImpl;
    address internal factoryRegistryImpl;
    address internal reserveV2Impl;
    address internal reserveLiquidityStrategyImpl;
    address internal cdpLiquidityStrategyImpl;

    // BiPoolManager (exchange provider) for virtual pool tests
    address internal biPoolManager;

    function setUp() public override {
        super.setUp();

        // Resolve implementation addresses from registry
        oracleAdapterImpl = lookupOrFail("OracleAdapter:v3.0.0");
        fpmmFactoryImpl = lookupOrFail("FPMMFactory:v3.0.0");
        factoryRegistryImpl = lookupOrFail("FactoryRegistry:v3.0.0");
        reserveV2Impl = lookupOrFail("ReserveV2:v3.0.0");
        reserveLiquidityStrategyImpl = lookupOrFail("ReserveLiquidityStrategy:v3.0.1");

        // Celo-only contracts
        if (_isCelo()) {
            cdpLiquidityStrategyImpl = lookupOrFail("CDPLiquidityStrategy:v3.0.0");
            biPoolManager = lookupProxyOrFail("BiPoolManager");
        }
    }

    // ========== Proxy → Implementation Mapping Tests ==========

    function test_oracleAdapter_proxyImpl() public view {
        address actual = getProxyImplementation(oracleAdapter);
        assertEq(actual, oracleAdapterImpl, "OracleAdapter proxy implementation mismatch");
    }

    function test_fpmmFactory_proxyImpl() public view {
        address actual = getProxyImplementation(fpmmFactory);
        assertEq(actual, fpmmFactoryImpl, "FPMMFactory proxy implementation mismatch");
    }

    function test_factoryRegistry_proxyImpl() public view {
        address actual = getProxyImplementation(factoryRegistry);
        assertEq(actual, factoryRegistryImpl, "FactoryRegistry proxy implementation mismatch");
    }

    function test_reserveV2_proxyImpl() public view {
        address actual = getProxyImplementation(reserveV2);
        assertEq(actual, reserveV2Impl, "ReserveV2 proxy implementation mismatch");
    }

    function test_reserveLiquidityStrategy_proxyImpl() public view {
        address actual = getProxyImplementation(reserveLiquidityStrategy);
        assertEq(actual, reserveLiquidityStrategyImpl, "ReserveLiquidityStrategy proxy implementation mismatch");
    }

    function test_cdpLiquidityStrategy_proxyImpl() public onlyCelo {
        address actual = getProxyImplementation(cdpLiquidityStrategy);
        assertEq(actual, cdpLiquidityStrategyImpl, "CDPLiquidityStrategy proxy implementation mismatch");
    }

    // ========== Init Disabled on Implementation Contracts ==========

    function test_oracleAdapterImpl_initDisabled() public {
        vm.expectRevert();
        IOracleAdapter(oracleAdapterImpl).initialize(address(1), address(2), address(3), address(4), address(5));
    }

    function test_fpmmFactoryImpl_initDisabled() public {
        IFPMM.FPMMParams memory params;
        vm.expectRevert();
        IFPMMFactory(fpmmFactoryImpl).initialize(address(1), address(2), address(3), address(4), params);
    }

    function test_factoryRegistryImpl_initDisabled() public {
        vm.expectRevert();
        IFactoryRegistry(factoryRegistryImpl).initialize(address(1), address(2));
    }

    function test_reserveV2Impl_initDisabled() public {
        address[] memory empty = new address[](0);
        vm.expectRevert();
        IReserveV2(reserveV2Impl).initialize(empty, empty, empty, empty, empty, address(1));
    }

    function test_reserveLiquidityStrategyImpl_initDisabled() public {
        vm.expectRevert();
        IReserveLiquidityStrategy(reserveLiquidityStrategyImpl).initialize(address(1), address(2));
    }

    function test_cdpLiquidityStrategyImpl_initDisabled() public onlyCelo {
        vm.expectRevert();
        ICDPLiquidityStrategy(cdpLiquidityStrategyImpl).initialize(address(1));
    }

    // ========== ProxyAdmin on FPMM Pool Proxies ==========

    function test_fpmmPools_proxyAdmin() public view {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            address poolAdmin = getProxyAdmin(pools[i]);
            assertEq(poolAdmin, proxyAdmin, string.concat("ProxyAdmin mismatch on FPMM pool at index ", vm.toString(i)));
        }
    }

    // ========== Ownership Tests ==========

    function test_oracleAdapter_owner() public view {
        assertEq(IOwnable(oracleAdapter).owner(), _getOwner(), "OracleAdapter owner mismatch");
    }

    function test_fpmmFactory_owner() public view {
        assertEq(IOwnable(fpmmFactory).owner(), _getOwner(), "FPMMFactory owner mismatch");
    }

    function test_factoryRegistry_owner() public view {
        assertEq(IOwnable(factoryRegistry).owner(), _getOwner(), "FactoryRegistry owner mismatch");
    }

    function test_virtualPoolFactory_owner() public onlyCelo {
        assertEq(IOwnable(virtualPoolFactory).owner(), _getOwner(), "VirtualPoolFactory owner mismatch");
    }

    function test_reserveV2_owner() public view {
        assertEq(IOwnable(reserveV2).owner(), _getOwner(), "ReserveV2 owner mismatch");
    }

    function test_reserveLiquidityStrategy_owner() public view {
        assertEq(IOwnable(reserveLiquidityStrategy).owner(), _getOwner(), "ReserveLiquidityStrategy owner mismatch");
    }

    function test_cdpLiquidityStrategy_owner() public onlyCelo {
        assertEq(IOwnable(cdpLiquidityStrategy).owner(), _getOwner(), "CDPLiquidityStrategy owner mismatch");
    }

    // ========== Non-Owner Access Denial Tests ==========

    function test_oracleAdapter_transferOwnership_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(oracleAdapter).transferOwnership(randomUser);
    }

    function test_fpmmFactory_transferOwnership_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(fpmmFactory).transferOwnership(randomUser);
    }

    function test_factoryRegistry_transferOwnership_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(factoryRegistry).transferOwnership(randomUser);
    }

    function test_virtualPoolFactory_transferOwnership_reverts_nonOwner() public onlyCelo {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(virtualPoolFactory).transferOwnership(randomUser);
    }

    function test_reserveV2_transferOwnership_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(reserveV2).transferOwnership(randomUser);
    }

    function test_reserveLiquidityStrategy_transferOwnership_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(reserveLiquidityStrategy).transferOwnership(randomUser);
    }

    function test_cdpLiquidityStrategy_transferOwnership_reverts_nonOwner() public onlyCelo {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IOwnable(cdpLiquidityStrategy).transferOwnership(randomUser);
    }

    // ========== FPMMFactory Access Control ==========

    function test_fpmmFactory_deployFPMM_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IFPMMFactory(fpmmFactory)
            .deployFPMM(
                fpmmFactoryImpl, // arbitrary implementation address
                address(1), // token0
                address(2), // token1
                address(3), // referenceRateFeedID
                false // invertRateFeed
            );
    }

    // ========== OracleAdapter Configuration Tests (US-004) ==========

    function test_oracleAdapter_sortedOracles() public view {
        address actual = address(IOracleAdapter(oracleAdapter).sortedOracles());
        assertEq(actual, sortedOracles, "OracleAdapter.sortedOracles() mismatch");
    }

    function test_oracleAdapter_breakerBox() public view {
        address actual = address(IOracleAdapter(oracleAdapter).breakerBox());
        assertEq(actual, breakerBox, "OracleAdapter.breakerBox() mismatch");
    }

    function test_oracleAdapter_marketHoursBreaker() public view {
        address actual = address(IOracleAdapter(oracleAdapter).marketHoursBreaker());
        assertEq(actual, marketHoursBreaker, "OracleAdapter.marketHoursBreaker() mismatch");
    }

    function test_oracleAdapter_l2SequencerUptimeFeed() public view {
        address actual = address(IOracleAdapter(oracleAdapter).l2SequencerUptimeFeed());
        assertEq(actual, l2SequencerUptimeFeed, "OracleAdapter.l2SequencerUptimeFeed() mismatch");
    }

    // ========== BreakerBox Configuration Tests (US-004) ==========

    function test_breakerBox_isBreaker_marketHoursBreaker() public view {
        assertTrue(
            IBreakerBox(breakerBox).isBreaker(marketHoursBreaker),
            "MarketHoursBreaker not registered as breaker in BreakerBox"
        );
    }

    function test_breakerBox_marketHoursBreaker_tradingMode() public view {
        uint8 tradingMode = IBreakerBox(breakerBox).breakerTradingMode(marketHoursBreaker);
        assertEq(tradingMode, 3, "MarketHoursBreaker trading mode should be 3 (trading halted)");
    }

    function test_marketHoursBreaker_enabledOnAllFxFeeds() public view {
        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            assertTrue(
                IBreakerBox(breakerBox).isBreakerEnabled(marketHoursBreaker, fxFeedIds[i]),
                string.concat("MarketHoursBreaker not enabled on FX feed: ", vm.toString(fxFeedIds[i]))
            );
        }
    }

    // ========== OracleAdapter FX Rate Validity Tests (US-004) ==========

    function test_oracleAdapter_getFXRateIfValid_allFeeds() public view {
        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            if (!IOracleAdapter(oracleAdapter).isFXMarketOpen()) {
                console.log("Market hours are closed, skipping feed: ", fxFeedIds[i]);
                continue;
            }

            (uint256 numerator, uint256 denominator) = IOracleAdapter(oracleAdapter).getFXRateIfValid(fxFeedIds[i]);
            assertGt(numerator, 0, string.concat("Zero numerator for FX feed: ", vm.toString(fxFeedIds[i])));
            assertGt(denominator, 0, string.concat("Zero denominator for FX feed: ", vm.toString(fxFeedIds[i])));
        }
    }

    // ========== FPMMFactory State Tests (US-005) ==========

    function test_fpmmFactory_oracleAdapter() public view {
        assertEq(IFPMMFactory(fpmmFactory).oracleAdapter(), oracleAdapter, "FPMMFactory.oracleAdapter() mismatch");
    }

    function test_fpmmFactory_proxyAdmin() public view {
        assertEq(IFPMMFactory(fpmmFactory).proxyAdmin(), proxyAdmin, "FPMMFactory.proxyAdmin() mismatch");
    }

    function test_fpmmFactory_defaultParams() public view {
        IFPMM.FPMMParams memory expected = config.getDefaultFPMMParams();
        IFPMM.FPMMParams memory actual = IFPMMFactory(fpmmFactory).defaultParams();

        assertEq(actual.lpFee, expected.lpFee, "FPMMFactory defaultParams lpFee mismatch");
        assertEq(actual.protocolFee, expected.protocolFee, "FPMMFactory defaultParams protocolFee mismatch");
        assertEq(
            actual.protocolFeeRecipient,
            expected.protocolFeeRecipient,
            "FPMMFactory defaultParams protocolFeeRecipient mismatch"
        );
        assertEq(actual.feeSetter, expected.feeSetter, "FPMMFactory defaultParams feeSetter mismatch");
        assertEq(
            actual.rebalanceIncentive,
            expected.rebalanceIncentive,
            "FPMMFactory defaultParams rebalanceIncentive mismatch"
        );
        assertEq(
            actual.rebalanceThresholdAbove,
            expected.rebalanceThresholdAbove,
            "FPMMFactory defaultParams rebalanceThresholdAbove mismatch"
        );
        assertEq(
            actual.rebalanceThresholdBelow,
            expected.rebalanceThresholdBelow,
            "FPMMFactory defaultParams rebalanceThresholdBelow mismatch"
        );
    }

    function test_fpmmFactory_isRegisteredImplementation() public view {
        address fpmmImpl = lookupOrFail("FPMM:v3.0.0");
        assertTrue(
            IFPMMFactory(fpmmFactory).isRegisteredImplementation(fpmmImpl),
            "FPMM implementation not registered in FPMMFactory"
        );
    }

    // ========== FactoryRegistry State Tests (US-005) ==========

    function test_factoryRegistry_fallbackPoolFactory() public view {
        assertEq(
            IFactoryRegistry(factoryRegistry).fallbackPoolFactory(),
            fpmmFactory,
            "FactoryRegistry.fallbackPoolFactory() should be FPMMFactory proxy"
        );
    }

    function test_factoryRegistry_isPoolFactoryApproved() public view {
        assertTrue(
            IFactoryRegistry(factoryRegistry).isPoolFactoryApproved(fpmmFactory),
            "FPMMFactory not approved in FactoryRegistry"
        );
    }

    // ========== Router State Tests (US-005) ==========

    function test_router_factoryRegistry() public view {
        assertEq(
            IRouter(router).factoryRegistry(),
            factoryRegistry,
            "Router.factoryRegistry() should be FactoryRegistry proxy"
        );
    }

    function test_router_defaultFactory() public view {
        assertEq(IRouter(router).defaultFactory(), fpmmFactory, "Router.defaultFactory() should be FPMMFactory proxy");
    }

    // ========== ReserveV2 Configuration Tests (US-006) ==========

    function test_reserveV2_reserveSafe_isOtherReserveAddress() public view {
        assertTrue(
            IReserveV2(reserveV2).isOtherReserveAddress(reserveSafe),
            "ReserveSafe not registered as other reserve address on ReserveV2"
        );
    }

    function test_reserveV2_reserveSafe_isReserveManagerSpender() public view {
        assertTrue(
            IReserveV2(reserveV2).isReserveManagerSpender(reserveSafe),
            "ReserveSafe not registered as reserve manager spender on ReserveV2"
        );
    }

    function test_reserveV2_reserveLiquidityStrategy_isLiquidityStrategySpender() public view {
        assertTrue(
            IReserveV2(reserveV2).isLiquidityStrategySpender(reserveLiquidityStrategy),
            "ReserveLiquidityStrategy not registered as liquidity strategy spender on ReserveV2"
        );
    }

    function test_reserveV2_registerStableAsset_reverts_nonOwner() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        vm.expectRevert();
        IReserveV2(reserveV2).registerStableAsset(address(1));
    }

    // ========== VirtualPool Deployment Tests (US-008) ==========

    /// @notice Verify virtual pools exist for all BiPoolManager exchanges marked createVirtual in config
    function test_virtualPools_existForAllCreateVirtualExchanges() public onlyCelo {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        uint256 virtualCount;
        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory exchangeConfig, bool found) =
                config.getExchangeConfig(pool.asset0, pool.asset1, address(pool.pricingModule));

            if (!found || !exchangeConfig.createVirtual) {
                continue;
            }

            virtualCount++;

            // Sort tokens for lookup
            (address token0, address token1) = _sortTokens(pool.asset0, pool.asset1);

            address virtualPool = IRPoolFactory(virtualPoolFactory).getPool(token0, token1);
            assertNotEq(
                virtualPool,
                address(0),
                string.concat("VirtualPool not deployed for exchange at index ", vm.toString(i))
            );
        }

        assertGt(virtualCount, 0, "No exchanges with createVirtual=true found in config");
    }

    /// @notice Verify virtual pool token0/token1 match the underlying exchange pair (sorted)
    function test_virtualPools_tokensMatchExchangePair() public onlyCelo {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory exchangeConfig, bool found) =
                config.getExchangeConfig(pool.asset0, pool.asset1, address(pool.pricingModule));

            if (!found || !exchangeConfig.createVirtual) {
                continue;
            }

            (address expectedToken0, address expectedToken1) = _sortTokens(pool.asset0, pool.asset1);

            address virtualPool = IRPoolFactory(virtualPoolFactory).getPool(expectedToken0, expectedToken1);
            require(virtualPool != address(0), "VirtualPool not found");

            (address actualToken0, address actualToken1) = IRPool(virtualPool).tokens();
            assertEq(
                actualToken0,
                expectedToken0,
                string.concat("VirtualPool token0 mismatch for exchange at index ", vm.toString(i))
            );
            assertEq(
                actualToken1,
                expectedToken1,
                string.concat("VirtualPool token1 mismatch for exchange at index ", vm.toString(i))
            );
        }
    }

    /// @notice Verify VirtualPoolFactory.isPool returns true for all deployed virtual pools
    function test_virtualPools_isPool() public onlyCelo {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory exchangeConfig, bool found) =
                config.getExchangeConfig(pool.asset0, pool.asset1, address(pool.pricingModule));

            if (!found || !exchangeConfig.createVirtual) {
                continue;
            }

            (address token0, address token1) = _sortTokens(pool.asset0, pool.asset1);
            address virtualPool = IRPoolFactory(virtualPoolFactory).getPool(token0, token1);

            assertTrue(
                IRPoolFactory(virtualPoolFactory).isPool(virtualPool),
                string.concat("VirtualPoolFactory.isPool() false for exchange at index ", vm.toString(i))
            );
        }
    }

    // ========== Internal Helpers ==========

    function _sortTokens(address a, address b) internal pure returns (address, address) {
        return (a > b) ? (b, a) : (a, b);
    }
}
