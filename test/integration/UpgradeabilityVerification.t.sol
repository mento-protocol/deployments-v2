// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {ICeloProxy} from "mento-core/interfaces/ICeloProxy.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IProxyAdmin {
    function upgradeAndCall(ITransparentUpgradeableProxy proxy, address implementation, bytes memory data)
        external
        payable;

    function owner() external view returns (address);
}

/**
 * @title UpgradeabilityVerification
 * @notice Verifies that all proxied contracts deployed as part of the deployment
 *         are actually upgradeable by the migrationOwner.
 *
 *         Handles two proxy types:
 *         - OZ TransparentUpgradeableProxy (v5): each proxy deploys its own ProxyAdmin,
 *           migrationOwner must own the ProxyAdmin, upgrade via ProxyAdmin.upgradeAndCall()
 *         - Celo Legacy Proxy: proxy owner is migrationOwner,
 *           upgrade via ICeloProxy._setImplementation()
 *
 *         Covers all deployed proxy contracts across both Celo and Monad:
 *         - V3 core (OZTUP): OracleAdapter, FPMMFactory, FactoryRegistry, ReserveV2,
 *           ReserveLiquidityStrategy, ChainlinkRelayerFactory, SortedOracles
 *         - Celo-only V3 (OZTUP): CDPLiquidityStrategy
 *         - Celo-only Liquity/CDP (OZTUP, per-token): FXPriceFeedProxy, StabilityPool, SystemParamsProxy
 *         - Celo-only Governance (OZTUP): Emission, Locking, MentoGovernor, TimelockController
 *         - Stable tokens: OZTUP (spoke) or Celo Legacy Proxy (hub), resolved dynamically
 *         - FPMM pool proxies (OZTUP, dynamic from FPMMFactory)
 */
contract UpgradeabilityVerification is V3IntegrationBase {
    address internal migrationOwner;
    address internal chainlinkRelayerFactory;
    address internal openLiquidityStrategy;

    // Stable token proxies (resolved dynamically from config, may be OZTUP or Celo Legacy)
    address[] internal stableTokenProxies;
    string[] internal stableTokenLabels;

    // Celo-only: Liquity/CDP proxy contracts (per-token, e.g., GBPm)
    address[] internal fxPriceFeedProxies;
    string[] internal fxPriceFeedLabels;
    address[] internal stabilityPoolProxies;
    string[] internal stabilityPoolLabels;
    address[] internal systemParamsProxies;
    string[] internal systemParamsLabels;

    // Celo-only: Governance proxy contracts
    address internal emission;
    address internal locking;
    address internal mentoGovernor;
    address internal timelockController;

    modifier onlyMonad() {
        if (_isCelo()) {
            vm.skip(true);
            return;
        }
        _;
    }

    function setUp() public override {
        super.setUp();
        migrationOwner = _getOwner();

        // ChainlinkRelayerFactory is present on all chains
        chainlinkRelayerFactory = lookupProxyOrFail("ChainlinkRelayerFactory");

        // Monad-only contracts
        if (!_isCelo()) {
            openLiquidityStrategy = lookupProxyOrFail("OpenLiquidityStrategy");
        }

        // Resolve stable token proxies from config (both OZTUP and Celo Legacy)
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();
        for (uint256 i = 0; i < tokens.length; i++) {
            // lookupProxyOrFail checks both Proxy:<symbol> and TransparentUpgradeableProxy:<symbol>
            address proxy = _lookupAnyProxy(tokens[i].symbol);
            if (proxy != address(0)) {
                stableTokenProxies.push(proxy);
                stableTokenLabels.push(tokens[i].symbol);
            }

            // Celo-only: Liquity/CDP proxies per token (always OZTUP)
            if (_isCelo()) {
                _tryAddLiquityProxy("FXPriceFeedProxy", tokens[i].symbol, fxPriceFeedProxies, fxPriceFeedLabels);
                _tryAddLiquityProxy("StabilityPool", tokens[i].symbol, stabilityPoolProxies, stabilityPoolLabels);
                _tryAddLiquityProxy("SystemParamsProxy", tokens[i].symbol, systemParamsProxies, systemParamsLabels);
            }
        }

        // Celo-only: Governance proxies
        if (_isCelo()) {
            emission = _lookupOztupProxy("Emission");
            locking = _lookupOztupProxy("Locking");
            mentoGovernor = _lookupOztupProxy("MentoGovernor");
            timelockController = _lookupOztupProxy("TimelockController");
        }
    }

    // ========== Per-Proxy Admin/Owner Verification ==========

    function test_oracleAdapter_proxyAdminOwnedByMigrationOwner() public view {
        _assertOztupProxyAdminOwner(oracleAdapter, "OracleAdapter");
    }

    function test_fpmmFactory_proxyAdminOwnedByMigrationOwner() public view {
        _assertOztupProxyAdminOwner(fpmmFactory, "FPMMFactory");
    }

    function test_factoryRegistry_proxyAdminOwnedByMigrationOwner() public view {
        _assertOztupProxyAdminOwner(factoryRegistry, "FactoryRegistry");
    }

    function test_reserveV2_proxyAdminOwnedByMigrationOwner() public view {
        _assertOztupProxyAdminOwner(reserveV2, "ReserveV2");
    }

    function test_reserveLiquidityStrategy_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _assertOztupProxyAdminOwner(reserveLiquidityStrategy, "ReserveLiquidityStrategy");
    }

    function test_openLiquidityStrategy_proxyAdminOwnedByMigrationOwner() public onlyMonad {
        _assertOztupProxyAdminOwner(openLiquidityStrategy, "OpenLiquidityStrategy");
    }

    function test_cdpLiquidityStrategy_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _assertOztupProxyAdminOwner(cdpLiquidityStrategy, "CDPLiquidityStrategy");
    }

    function test_chainlinkRelayerFactory_proxyAdminOwnedByMigrationOwner() public view {
        _assertOztupProxyAdminOwner(chainlinkRelayerFactory, "ChainlinkRelayerFactory");
    }

    function test_sortedOracles_proxyAdminOwnedByMigrationOwner() public view {
        _assertUpgradeAuthorityOwnedByMigrationOwner(sortedOracles, "SortedOracles");
    }

    function test_stableTokens_upgradeAuthorityOwnedByMigrationOwner() public view {
        assertGt(stableTokenProxies.length, 0, "No stable token proxies found");
        for (uint256 i = 0; i < stableTokenProxies.length; i++) {
            _assertUpgradeAuthorityOwnedByMigrationOwner(stableTokenProxies[i], stableTokenLabels[i]);
        }
    }

    function test_fpmmPools_proxyAdminOwnedByMigrationOwner() public view {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            address poolAdmin = getProxyAdmin(pools[i]);
            assertEq(
                IProxyAdmin(poolAdmin).owner(),
                migrationOwner,
                string.concat("FPMM pool ProxyAdmin not owned by migrationOwner at index ", vm.toString(i))
            );
        }
    }

    // ── Celo-only: Liquity/CDP proxies ──

    function test_fxPriceFeedProxies_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        assertGt(fxPriceFeedProxies.length, 0, "No FXPriceFeed proxies found");
        for (uint256 i = 0; i < fxPriceFeedProxies.length; i++) {
            _assertOztupProxyAdminOwner(fxPriceFeedProxies[i], string.concat("FXPriceFeedProxy:", fxPriceFeedLabels[i]));
        }
    }

    function test_stabilityPoolProxies_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        assertGt(stabilityPoolProxies.length, 0, "No StabilityPool proxies found");
        for (uint256 i = 0; i < stabilityPoolProxies.length; i++) {
            _assertOztupProxyAdminOwner(
                stabilityPoolProxies[i], string.concat("StabilityPool:", stabilityPoolLabels[i])
            );
        }
    }

    function test_systemParamsProxies_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        assertGt(systemParamsProxies.length, 0, "No SystemParams proxies found");
        for (uint256 i = 0; i < systemParamsProxies.length; i++) {
            _assertOztupProxyAdminOwner(
                systemParamsProxies[i], string.concat("SystemParamsProxy:", systemParamsLabels[i])
            );
        }
    }

    // ── Celo-only: Governance proxies ──

    function test_emission_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _skipIfZero(emission);
        _assertOztupProxyAdminOwner(emission, "Emission");
    }

    function test_locking_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _skipIfZero(locking);
        _assertOztupProxyAdminOwner(locking, "Locking");
    }

    function test_mentoGovernor_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _skipIfZero(mentoGovernor);
        _assertOztupProxyAdminOwner(mentoGovernor, "MentoGovernor");
    }

    function test_timelockController_proxyAdminOwnedByMigrationOwner() public onlyCelo {
        _skipIfZero(timelockController);
        _assertOztupProxyAdminOwner(timelockController, "TimelockController");
    }

    // ========== Upgrade Tests: migrationOwner CAN upgrade ==========

    function test_migrationOwner_canUpgrade_oracleAdapter() public {
        _assertCanUpgradeOztup(oracleAdapter, "OracleAdapter");
    }

    function test_migrationOwner_canUpgrade_fpmmFactory() public {
        _assertCanUpgradeOztup(fpmmFactory, "FPMMFactory");
    }

    function test_migrationOwner_canUpgrade_factoryRegistry() public {
        _assertCanUpgradeOztup(factoryRegistry, "FactoryRegistry");
    }

    function test_migrationOwner_canUpgrade_reserveV2() public {
        _assertCanUpgradeOztup(reserveV2, "ReserveV2");
    }

    function test_migrationOwner_canUpgrade_reserveLiquidityStrategy() public onlyCelo {
        _assertCanUpgradeOztup(reserveLiquidityStrategy, "ReserveLiquidityStrategy");
    }

    function test_migrationOwner_canUpgrade_openLiquidityStrategy() public onlyMonad {
        _assertCanUpgradeOztup(openLiquidityStrategy, "OpenLiquidityStrategy");
    }

    function test_migrationOwner_canUpgrade_cdpLiquidityStrategy() public onlyCelo {
        _assertCanUpgradeOztup(cdpLiquidityStrategy, "CDPLiquidityStrategy");
    }

    function test_migrationOwner_canUpgrade_chainlinkRelayerFactory() public {
        _assertCanUpgradeOztup(chainlinkRelayerFactory, "ChainlinkRelayerFactory");
    }

    function test_migrationOwner_canUpgrade_sortedOracles() public {
        _assertCanUpgrade(sortedOracles, "SortedOracles");
    }

    function test_migrationOwner_canUpgrade_stableTokens() public {
        assertGt(stableTokenProxies.length, 0, "No stable token proxies found");
        for (uint256 i = 0; i < stableTokenProxies.length; i++) {
            _assertCanUpgrade(stableTokenProxies[i], stableTokenLabels[i]);
        }
    }

    function test_migrationOwner_canUpgrade_fpmmPools() public {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            _assertCanUpgradeOztup(pools[i], string.concat("FPMMPool[", vm.toString(i), "]"));
        }
    }

    // ── Celo-only: Liquity/CDP proxies ──

    function test_migrationOwner_canUpgrade_fxPriceFeedProxies() public onlyCelo {
        assertGt(fxPriceFeedProxies.length, 0, "No FXPriceFeed proxies found");
        for (uint256 i = 0; i < fxPriceFeedProxies.length; i++) {
            _assertCanUpgradeOztup(fxPriceFeedProxies[i], string.concat("FXPriceFeedProxy:", fxPriceFeedLabels[i]));
        }
    }

    function test_migrationOwner_canUpgrade_stabilityPoolProxies() public onlyCelo {
        assertGt(stabilityPoolProxies.length, 0, "No StabilityPool proxies found");
        for (uint256 i = 0; i < stabilityPoolProxies.length; i++) {
            _assertCanUpgradeOztup(stabilityPoolProxies[i], string.concat("StabilityPool:", stabilityPoolLabels[i]));
        }
    }

    function test_migrationOwner_canUpgrade_systemParamsProxies() public onlyCelo {
        assertGt(systemParamsProxies.length, 0, "No SystemParams proxies found");
        for (uint256 i = 0; i < systemParamsProxies.length; i++) {
            _assertCanUpgradeOztup(systemParamsProxies[i], string.concat("SystemParamsProxy:", systemParamsLabels[i]));
        }
    }

    // ── Celo-only: Governance proxies ──

    function test_migrationOwner_canUpgrade_emission() public onlyCelo {
        _skipIfZero(emission);
        _assertCanUpgradeOztup(emission, "Emission");
    }

    function test_migrationOwner_canUpgrade_locking() public onlyCelo {
        _skipIfZero(locking);
        _assertCanUpgradeOztup(locking, "Locking");
    }

    function test_migrationOwner_canUpgrade_mentoGovernor() public onlyCelo {
        _skipIfZero(mentoGovernor);
        _assertCanUpgradeOztup(mentoGovernor, "MentoGovernor");
    }

    function test_migrationOwner_canUpgrade_timelockController() public onlyCelo {
        _skipIfZero(timelockController);
        _assertCanUpgradeOztup(timelockController, "TimelockController");
    }

    // ========== Non-Owner Cannot Upgrade ==========

    function test_nonOwner_cannotUpgrade_oracleAdapter() public {
        _assertNonOwnerCannotUpgradeOztup(oracleAdapter);
    }

    function test_nonOwner_cannotUpgrade_fpmmFactory() public {
        _assertNonOwnerCannotUpgradeOztup(fpmmFactory);
    }

    function test_nonOwner_cannotUpgrade_factoryRegistry() public {
        _assertNonOwnerCannotUpgradeOztup(factoryRegistry);
    }

    function test_nonOwner_cannotUpgrade_reserveV2() public {
        _assertNonOwnerCannotUpgradeOztup(reserveV2);
    }

    function test_nonOwner_cannotUpgrade_reserveLiquidityStrategy() public onlyCelo {
        _assertNonOwnerCannotUpgradeOztup(reserveLiquidityStrategy);
    }

    function test_nonOwner_cannotUpgrade_openLiquidityStrategy() public onlyMonad {
        _assertNonOwnerCannotUpgradeOztup(openLiquidityStrategy);
    }

    function test_nonOwner_cannotUpgrade_cdpLiquidityStrategy() public onlyCelo {
        _assertNonOwnerCannotUpgradeOztup(cdpLiquidityStrategy);
    }

    function test_nonOwner_cannotUpgrade_chainlinkRelayerFactory() public {
        _assertNonOwnerCannotUpgradeOztup(chainlinkRelayerFactory);
    }

    function test_nonOwner_cannotUpgrade_sortedOracles() public {
        _assertNonOwnerCannotUpgrade(sortedOracles);
    }

    function test_nonOwner_cannotUpgrade_stableTokens() public {
        assertGt(stableTokenProxies.length, 0, "No stable token proxies found");
        for (uint256 i = 0; i < stableTokenProxies.length; i++) {
            _assertNonOwnerCannotUpgrade(stableTokenProxies[i]);
        }
    }

    function test_nonOwner_cannotUpgrade_fpmmPools() public {
        address[] memory pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
        assertGt(pools.length, 0, "No FPMM pools deployed");

        for (uint256 i = 0; i < pools.length; i++) {
            _assertNonOwnerCannotUpgradeOztup(pools[i]);
        }
    }

    // ── Celo-only: Liquity/CDP proxies ──

    function test_nonOwner_cannotUpgrade_fxPriceFeedProxies() public onlyCelo {
        assertGt(fxPriceFeedProxies.length, 0, "No FXPriceFeed proxies found");
        for (uint256 i = 0; i < fxPriceFeedProxies.length; i++) {
            _assertNonOwnerCannotUpgradeOztup(fxPriceFeedProxies[i]);
        }
    }

    function test_nonOwner_cannotUpgrade_stabilityPoolProxies() public onlyCelo {
        assertGt(stabilityPoolProxies.length, 0, "No StabilityPool proxies found");
        for (uint256 i = 0; i < stabilityPoolProxies.length; i++) {
            _assertNonOwnerCannotUpgradeOztup(stabilityPoolProxies[i]);
        }
    }

    function test_nonOwner_cannotUpgrade_systemParamsProxies() public onlyCelo {
        assertGt(systemParamsProxies.length, 0, "No SystemParams proxies found");
        for (uint256 i = 0; i < systemParamsProxies.length; i++) {
            _assertNonOwnerCannotUpgradeOztup(systemParamsProxies[i]);
        }
    }

    // ── Celo-only: Governance proxies ──

    function test_nonOwner_cannotUpgrade_emission() public onlyCelo {
        _skipIfZero(emission);
        _assertNonOwnerCannotUpgradeOztup(emission);
    }

    function test_nonOwner_cannotUpgrade_locking() public onlyCelo {
        _skipIfZero(locking);
        _assertNonOwnerCannotUpgradeOztup(locking);
    }

    function test_nonOwner_cannotUpgrade_mentoGovernor() public onlyCelo {
        _skipIfZero(mentoGovernor);
        _assertNonOwnerCannotUpgradeOztup(mentoGovernor);
    }

    function test_nonOwner_cannotUpgrade_timelockController() public onlyCelo {
        _skipIfZero(timelockController);
        _assertNonOwnerCannotUpgradeOztup(timelockController);
    }

    // ========== Internal Helpers ==========

    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev Deploys a minimal dummy contract to use as a new implementation target.
    function _deployDummyImplementation() internal returns (address) {
        return address(new DummyImplementation());
    }

    /// @dev Reads the implementation address directly from the EIP-1967 storage slot.
    ///      Unlike getProxyImplementation(), this does not call the proxy's interface,
    ///      so it works even after upgrading to DummyImplementation (which lacks _getImplementation).
    function _readImplSlot(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, _IMPL_SLOT))));
    }

    /// @dev Detects whether a proxy is Celo Legacy (has _getOwner) or OZTUP.
    function _isCeloLegacyProxy(address proxy) internal view returns (bool) {
        try ICeloProxy(proxy)._getOwner() returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    // ── Ownership assertions ──

    /// @dev For OZTUP proxies: asserts the per-proxy ProxyAdmin is owned by migrationOwner.
    function _assertOztupProxyAdminOwner(address proxy, string memory label) internal view {
        address perProxyAdmin = getProxyAdmin(proxy);
        assertEq(
            IProxyAdmin(perProxyAdmin).owner(),
            migrationOwner,
            string.concat(label, " ProxyAdmin not owned by migrationOwner")
        );
    }

    /// @dev For either proxy type: asserts the upgrade authority is migrationOwner.
    function _assertUpgradeAuthorityOwnedByMigrationOwner(address proxy, string memory label) internal view {
        if (_isCeloLegacyProxy(proxy)) {
            assertEq(
                ICeloProxy(proxy)._getOwner(),
                migrationOwner,
                string.concat(label, " Celo proxy not owned by migrationOwner")
            );
        } else {
            _assertOztupProxyAdminOwner(proxy, label);
        }
    }

    // ── Upgrade assertions ──

    /// @dev For OZTUP proxies: asserts migrationOwner can upgrade via ProxyAdmin.
    function _assertCanUpgradeOztup(address proxy, string memory label) internal {
        address perProxyAdmin = getProxyAdmin(proxy);
        address dummyImpl = _deployDummyImplementation();
        address implBefore = _readImplSlot(proxy);

        vm.prank(migrationOwner);
        IProxyAdmin(perProxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), dummyImpl, "");

        address implAfter = _readImplSlot(proxy);
        assertEq(implAfter, dummyImpl, string.concat(label, ": upgrade did not change implementation"));
        assertFalse(implAfter == implBefore, string.concat(label, ": implementation unchanged after upgrade"));
    }

    /// @dev For Celo Legacy proxies: asserts migrationOwner can upgrade via _setImplementation.
    function _assertCanUpgradeCeloLegacy(address proxy, string memory label) internal {
        address dummyImpl = _deployDummyImplementation();
        address implBefore = getProxyImplementation(proxy);

        vm.prank(migrationOwner);
        ICeloProxy(proxy)._setImplementation(dummyImpl);

        // Celo Legacy proxies may not use EIP-1967 slot, so read via the proxy interface.
        // After _setImplementation, _getImplementation on the proxy itself (not delegated) still works.
        address implAfter = getProxyImplementation(proxy);
        assertEq(implAfter, dummyImpl, string.concat(label, ": upgrade did not change implementation"));
        assertFalse(implAfter == implBefore, string.concat(label, ": implementation unchanged after upgrade"));
    }

    /// @dev For either proxy type: asserts migrationOwner can upgrade.
    function _assertCanUpgrade(address proxy, string memory label) internal {
        if (_isCeloLegacyProxy(proxy)) {
            _assertCanUpgradeCeloLegacy(proxy, label);
        } else {
            _assertCanUpgradeOztup(proxy, label);
        }
    }

    // ── Non-owner cannot upgrade assertions ──

    /// @dev For OZTUP proxies: asserts a non-owner cannot upgrade.
    function _assertNonOwnerCannotUpgradeOztup(address proxy) internal {
        address perProxyAdmin = getProxyAdmin(proxy);
        address dummyImpl = _deployDummyImplementation();
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        vm.expectRevert();
        IProxyAdmin(perProxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), dummyImpl, "");
    }

    /// @dev For Celo Legacy proxies: asserts a non-owner cannot upgrade.
    function _assertNonOwnerCannotUpgradeCeloLegacy(address proxy) internal {
        address dummyImpl = _deployDummyImplementation();
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        vm.expectRevert();
        ICeloProxy(proxy)._setImplementation(dummyImpl);
    }

    /// @dev For either proxy type: asserts a non-owner cannot upgrade.
    function _assertNonOwnerCannotUpgrade(address proxy) internal {
        if (_isCeloLegacyProxy(proxy)) {
            _assertNonOwnerCannotUpgradeCeloLegacy(proxy);
        } else {
            _assertNonOwnerCannotUpgradeOztup(proxy);
        }
    }

    // ── Lookup helpers ──

    /// @dev Looks up a proxy by name, checking both Celo Legacy and OZTUP prefixes.
    ///      Returns address(0) if not found.
    function _lookupAnyProxy(string memory contractName) internal view returns (address) {
        address celo = registry.lookup(string.concat("Proxy:", contractName));
        address oztup = registry.lookup(string.concat("TransparentUpgradeableProxy:", contractName));
        return celo != address(0) ? celo : oztup;
    }

    /// @dev Tries to look up a Liquity proxy (e.g., "StabilityPool:GBPm") and adds it to the arrays if found.
    function _tryAddLiquityProxy(
        string memory proxyType,
        string memory tokenSymbol,
        address[] storage proxies,
        string[] storage labels
    ) internal {
        string memory key = string.concat("TransparentUpgradeableProxy:", proxyType, ":", tokenSymbol);
        address proxy = registry.lookup(key);
        if (proxy != address(0)) {
            proxies.push(proxy);
            labels.push(tokenSymbol);
        }
    }

    /// @dev Looks up an OZTUP proxy, returns address(0) if not found.
    function _lookupOztupProxy(string memory contractName) internal view returns (address) {
        return registry.lookup(string.concat("TransparentUpgradeableProxy:", contractName));
    }

    /// @dev Skips the test if the address is zero (contract not deployed on this network).
    function _skipIfZero(address addr) internal {
        if (addr == address(0)) {
            vm.skip(true);
        }
    }
}

/// @dev Minimal contract used as a dummy implementation for upgrade tests.
///      Includes a fallback so that delegate calls with empty data (from OZ v4
///      TransparentUpgradeableProxy.upgradeToAndCall with forceCall=true) succeed.
contract DummyImplementation {
    uint256 private _placeholder;

    fallback() external payable {}
    receive() external payable {}
}
