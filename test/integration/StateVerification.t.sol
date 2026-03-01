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

/**
 * @title StateVerification
 * @notice Verifies proxy implementations, init protection, and ProxyAdmin config for V3 contracts.
 */
contract StateVerification is V3IntegrationBase {
    // Implementation addresses resolved in setUp
    address internal oracleAdapterImpl;
    address internal fpmmFactoryImpl;
    address internal factoryRegistryImpl;
    address internal reserveV2Impl;
    address internal reserveLiquidityStrategyImpl;
    address internal cdpLiquidityStrategyImpl;

    function setUp() public override {
        super.setUp();

        // Resolve implementation addresses from registry
        oracleAdapterImpl = lookupOrFail("OracleAdapter:v3.0.0");
        fpmmFactoryImpl = lookupOrFail("FPMMFactory:v3.0.0");
        factoryRegistryImpl = lookupOrFail("FactoryRegistry:v3.0.0");
        reserveV2Impl = lookupOrFail("ReserveV2:v3.0.0");
        reserveLiquidityStrategyImpl = lookupOrFail("ReserveLiquidityStrategy:v3.0.0");
        cdpLiquidityStrategyImpl = lookupOrFail("CDPLiquidityStrategy:v3.0.0");
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

    function test_cdpLiquidityStrategy_proxyImpl() public view {
        address actual = getProxyImplementation(cdpLiquidityStrategy);
        assertEq(actual, cdpLiquidityStrategyImpl, "CDPLiquidityStrategy proxy implementation mismatch");
    }

    // ========== Init Disabled on Implementation Contracts ==========

    function test_oracleAdapterImpl_initDisabled() public {
        vm.expectRevert();
        IOracleAdapter(oracleAdapterImpl).initialize(
            address(1), address(2), address(3), address(4), address(5)
        );
    }

    function test_fpmmFactoryImpl_initDisabled() public {
        IFPMM.FPMMParams memory params;
        vm.expectRevert();
        IFPMMFactory(fpmmFactoryImpl).initialize(
            address(1), address(2), address(3), address(4), params
        );
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

    function test_cdpLiquidityStrategyImpl_initDisabled() public {
        vm.expectRevert();
        ICDPLiquidityStrategy(cdpLiquidityStrategyImpl).initialize(address(1));
    }

    // ========== ProxyAdmin on FPMM Pool Proxies ==========

    function test_fpmmPools_proxyAdmin() public view {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            address poolAdmin = getProxyAdmin(pools[i]);
            assertEq(
                poolAdmin,
                proxyAdmin,
                string.concat("ProxyAdmin mismatch on FPMM pool at index ", vm.toString(i))
            );
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

    function test_virtualPoolFactory_owner() public view {
        assertEq(IOwnable(virtualPoolFactory).owner(), _getOwner(), "VirtualPoolFactory owner mismatch");
    }

    function test_reserveV2_owner() public view {
        assertEq(IOwnable(reserveV2).owner(), _getOwner(), "ReserveV2 owner mismatch");
    }

    function test_reserveLiquidityStrategy_owner() public view {
        assertEq(IOwnable(reserveLiquidityStrategy).owner(), _getOwner(), "ReserveLiquidityStrategy owner mismatch");
    }

    function test_cdpLiquidityStrategy_owner() public view {
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

    function test_virtualPoolFactory_transferOwnership_reverts_nonOwner() public {
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

    function test_cdpLiquidityStrategy_transferOwnership_reverts_nonOwner() public {
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
        IFPMMFactory(fpmmFactory).deployFPMM(
            fpmmFactoryImpl, // arbitrary implementation address
            address(1),      // token0
            address(2),      // token1
            address(3),      // referenceRateFeedID
            false            // invertRateFeed
        );
    }
}
