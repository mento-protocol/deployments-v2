// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";
import {IStableTokenV3} from "lib/mento-core/contracts/interfaces/IStableTokenV3.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {IMedianDeltaBreaker} from "lib/mento-core/contracts/interfaces/IMedianDeltaBreaker.sol";
import {IValueDeltaBreaker} from "lib/mento-core/contracts/interfaces/IValueDeltaBreaker.sol";
import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

/// @dev Celo core Registry (same address on every Celo network).
interface ICeloRegistry {
    function getAddressForString(string calldata identifier) external view returns (address);
}

/// @dev OZ v5 ProxyAdmin (each TransparentUpgradeableProxy in the V3 stack has its own).
interface IProxyAdminV5 {
    function owner() external view returns (address);
    function upgradeAndCall(address proxy, address implementation, bytes calldata data) external payable;
}

/// @dev Minimal admin surface of the legacy StableTokenV2 implementation.
interface IStableTokenV2Admin {
    function broker() external view returns (address);
    function setBroker(address _broker) external;
}

/// @dev Minimal admin surface of the Broker implementation deployed on Celo (single reserve).
interface IBrokerAdminView {
    function reserve() external view returns (address);
    function setReserve(address _reserve) external;
}

/// @dev Minimal admin surface of the ChainlinkRelayerFactory.
interface IChainlinkRelayerFactoryAdmin {
    function relayerDeployer() external view returns (address);
    function setRelayerDeployer(address newRelayerDeployer) external;
}

/// @dev src/ProposalDependencyGuard.sol. `requireSettled` is deliberately declared non-view here so that a call
///      through a treb harness is queued as a proposal transaction (a staticcall would only be forwarded).
interface IProposalDependencyGuardCall {
    function requireSettled(address governor, uint256 proposalId) external;
    function isSettled(address governor, uint256 proposalId) external view returns (bool);
}

/**
 * @title MGP19
 * @notice Returns on-chain control of the Mento *issuance* protocol on Celo to Celo Governance.
 *
 *  Scope (issuance side, transferred to Celo Governance):
 *    - all 15 Mento stable assets (proxy admin + contract owner)
 *    - direct reserve elastic mint/burn: Broker, BiPoolManager, Reserve (v1)
 *    - V3 reserve issuance: ReserveV2, ReserveLiquidityStrategy, CDPLiquidityStrategy, ReserveTroveFactory
 *    - CDP branches (GBPm, CHFm, JPYm): FXPriceFeed (owner + proxy admin), SystemParams and StabilityPool
 *      proxy admins (their parameters change only via upgrade)
 *    - the oracle layer that gates minting/burning: SortedOracles, BreakerBox, MedianDeltaBreaker,
 *      ValueDeltaBreaker, ChainlinkRelayerFactory (contract owner)
 *
 *  Out of scope (stays with Mento Governance / Mento Labs): the FX DEX (FPMMFactory, FactoryRegistry,
 *  FPMMs, Router, VirtualPoolFactory, OpenLiquidityStrategy, OracleAdapter(s), MarketHoursBreaker) and
 *  the DAO (MentoGovernor, TimelockController, Locking, MENTO token and their ProxyAdmin).
 *
 *  Rights are today split between the Mento Governance timelock and the Mento Labs migration multisig
 *  (temporarily entrusted in MGP-14 / MGP-16). This script therefore drives two senders:
 *    - `governor`       -> one Mento Governance proposal covering everything the timelock holds
 *    - `migrationOwner` -> one Safe batch covering everything the migration multisig holds
 *  Every right is routed to the sender that currently holds it, and the script reverts if any right
 *  is held by anyone else. Post-checks assert that Celo Governance holds every right, that out-of-scope
 *  contracts are untouched, and that Celo Governance can actually exercise the transferred powers.
 */
contract MGP19 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    uint256 internal constant CELO_MAINNET_CHAIN_ID = 42220;
    address internal constant CELO_REGISTRY = 0x000000000000000000000000000000000000ce10;
    /// @dev Celo Governance proxy on Celo mainnet (Registry: "Governance").
    address internal constant MAINNET_CELO_GOVERNANCE = 0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972;

    enum Kind {
        CeloProxy, // Celo legacy proxy: proxy admin (_getOwner) + Ownable contract behind it
        OZTUP, // OZ TransparentUpgradeableProxy: dedicated ProxyAdmin + Ownable contract behind it
        OZTUPAdminOnly, // OZ TransparentUpgradeableProxy whose implementation has no owner
        Ownable // plain Ownable singleton (no proxy)
    }

    struct Target {
        string name;
        address addr;
        Kind kind;
    }

    /// @dev Snapshot of an out-of-scope right that must be untouched by this proposal.
    struct Guard {
        string name;
        address addr;
        bool proxyAdminRight; // true: check proxy admin owner, false: check contract owner
        address expected;
    }

    Target[] internal tokensV2; // legacy StableTokenV2 assets (Celo proxy)
    Target[] internal tokensV3; // StableTokenV3 assets (Celo proxy)
    Target[] internal core; // Broker, BiPoolManager, Reserve, SortedOracles (Celo proxy)
    Target[] internal singletons; // BreakerBox, breakers, ReserveTroveFactory (Ownable)
    Target[] internal v3Proxies; // ReserveV2, RLS, CDPLS, FXPriceFeeds, ChainlinkRelayerFactory (OZ TUP)
    Target[] internal cdpAdminOnly; // SystemParams + StabilityPool proxies (OZ TUP, admin only)
    Guard[] internal guards;

    address internal celoGovernance;
    address internal timelock;
    address internal migrationSafe;

    uint256 internal governorTxCount;
    uint256 internal safeTxCount;

    uint256 internal dependsOnProposalId;
    address internal dependencyGuard;

    // ---------------------------------------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------------------------------------

    function setUp() public {
        celoGovernance = ICeloRegistry(CELO_REGISTRY).getAddressForString("Governance");
        require(celoGovernance != address(0), "Celo Governance not found in Celo Registry");
        if (block.chainid == CELO_MAINNET_CHAIN_ID) {
            require(celoGovernance == MAINNET_CELO_GOVERNANCE, "unexpected Celo Governance address");
        }

        timelock = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);

        // ---- Stable assets --------------------------------------------------------------------
        addCeloProxy(tokensV2, "BRLm");
        addCeloProxy(tokensV2, "XOFm");
        addCeloProxy(tokensV2, "KESm");
        addCeloProxy(tokensV2, "PHPm");
        addCeloProxy(tokensV2, "COPm");
        addCeloProxy(tokensV2, "GHSm");
        addCeloProxy(tokensV2, "ZARm");
        addCeloProxy(tokensV2, "CADm");
        addCeloProxy(tokensV2, "AUDm");
        addCeloProxy(tokensV2, "NGNm");

        addCeloProxy(tokensV3, "USDm");
        addCeloProxy(tokensV3, "EURm");
        addCeloProxy(tokensV3, "GBPm");
        addCeloProxy(tokensV3, "CHFm");
        addCeloProxy(tokensV3, "JPYm");

        // ---- Direct reserve mint/burn (Mento V2) + oracle layer ------------------------------
        addCeloProxy(core, "Broker");
        addCeloProxy(core, "BiPoolManager");
        addCeloProxy(core, "Reserve");
        addCeloProxy(core, "SortedOracles");

        addOwnable(singletons, "BreakerBox", "BreakerBox:v2.6.5");
        addOwnable(singletons, "MedianDeltaBreaker", "MedianDeltaBreaker:v2.6.5");
        addOwnable(singletons, "ValueDeltaBreaker", "ValueDeltaBreaker:v2.6.5");
        addOwnable(singletons, "ReserveTroveFactory", "ReserveTroveFactory");

        // ---- Mento V3 reserve issuance + CDP branches ----------------------------------------
        addOZTUP(v3Proxies, "ReserveV2", Kind.OZTUP);
        addOZTUP(v3Proxies, "ReserveLiquidityStrategy", Kind.OZTUP);
        addOZTUP(v3Proxies, "CDPLiquidityStrategy", Kind.OZTUP);
        addOZTUP(v3Proxies, "FXPriceFeedProxy:GBPm", Kind.OZTUP);
        addOZTUP(v3Proxies, "FXPriceFeedProxy:CHFm", Kind.OZTUP);
        addOZTUP(v3Proxies, "FXPriceFeedProxy:JPYm", Kind.OZTUP);
        // ChainlinkRelayerFactory: only the contract owner is transferred here. Its ProxyAdmin is owned
        // by a legacy Mento Labs Safe (not a treb sender) and is handled out of band, see mgp19.md.
        addOZTUP(v3Proxies, "ChainlinkRelayerFactory", Kind.Ownable);

        addOZTUP(cdpAdminOnly, "SystemParamsProxy:GBPm", Kind.OZTUPAdminOnly);
        addOZTUP(cdpAdminOnly, "SystemParamsProxy:CHFm", Kind.OZTUPAdminOnly);
        addOZTUP(cdpAdminOnly, "SystemParamsProxy:JPYm", Kind.OZTUPAdminOnly);
        addOZTUP(cdpAdminOnly, "StabilityPool:GBPm", Kind.OZTUPAdminOnly);
        addOZTUP(cdpAdminOnly, "StabilityPool:CHFm", Kind.OZTUPAdminOnly);
        addOZTUP(cdpAdminOnly, "StabilityPool:JPYm", Kind.OZTUPAdminOnly);
    }

    /// @custom:env {uint256:optional} dependsOnProposalId Mento Governance proposal id (e.g. MGP-18) that must have
    ///         settled before this proposal can execute. When set, the first proposal transaction calls
    ///         ProposalDependencyGuard.requireSettled(governor, id), which reverts while that proposal is Pending,
    ///         Active, Succeeded or Queued.
    /// @custom:senders deployer, governor, migrationOwner
    function run() public virtual broadcast {
        Senders.Sender storage govSender = sender("governor");
        migrationSafe = sender("migrationOwner").account;
        require(migrationSafe != address(0), "migrationOwner not configured");
        require(govSender.account == timelock, "governor sender does not execute as the Mento timelock");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-19: Returning the Mento Issuance Protocol to Celo");
        ozGovSender.setProposalDescription("./mgps/mgp19.md");

        dependsOnProposalId = vm.envOr("dependsOnProposalId", uint256(0));

        setUpGuards();

        preChecks();

        if (dependsOnProposalId != 0) {
            queueDependencyGuard(govSender, ozGovSender.governor);
        }

        transferAll();

        postChecks();
    }

    // ---------------------------------------------------------------------------------------------
    // Ordering with respect to another proposal (MGP-18)
    // ---------------------------------------------------------------------------------------------

    /// @dev Adds `ProposalDependencyGuard.requireSettled(governor, dependsOnProposalId)` as the first transaction
    ///      of the governance proposal. The dependency is normally still in flight when this proposal is created,
    ///      so the call is mocked for the simulation only; on-chain it is enforced at execution time (a revert
    ///      keeps this proposal Queued until the dependency has executed or died).
    function queueDependencyGuard(Senders.Sender storage govSender, address governor) internal {
        console.log("");
        console.log("== Ordering guard ==");
        dependencyGuard = lookup("ProposalDependencyGuard");
        if (dependencyGuard == address(0)) {
            dependencyGuard = sender("deployer").create3("ProposalDependencyGuard").deploy();
            console.log(" > deployed ProposalDependencyGuard at %s", dependencyGuard);
        } else {
            console.log(" > using ProposalDependencyGuard at %s", dependencyGuard);
        }
        console.log(" > proposal will not execute before proposal %d on %s has settled", dependsOnProposalId, governor);

        bytes memory data = abi.encodeCall(IProposalDependencyGuardCall.requireSettled, (governor, dependsOnProposalId));
        vm.mockCall(dependencyGuard, data, "");
        IProposalDependencyGuardCall(govSender.harness(dependencyGuard)).requireSettled(governor, dependsOnProposalId);
        vm.clearMockedCalls();
        governorTxCount++;
    }

    function checkDependencyGuard(address governor) internal {
        console.log("");
        console.log(" (ordering guard)");
        bool settled = IProposalDependencyGuardCall(dependencyGuard).isSettled(governor, dependsOnProposalId);
        if (settled) {
            IProposalDependencyGuardCall(dependencyGuard).requireSettled(governor, dependsOnProposalId);
            console.log(
                unicode"  > 🟢 proposal %d has settled; the guard lets this proposal execute", dependsOnProposalId
            );
        } else {
            vm.expectRevert();
            IProposalDependencyGuardCall(dependencyGuard).requireSettled(governor, dependsOnProposalId);
            console.log(
                unicode"  > 🟡 proposal %d has not settled yet; the guard currently blocks execution (as intended)",
                dependsOnProposalId
            );
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Transfers
    // ---------------------------------------------------------------------------------------------

    function transferAll() internal {
        console.log("");
        console.log("== Transferring issuance rights to Celo Governance %s ==", celoGovernance);

        console.log("");
        console.log(" (stable assets - StableTokenV2)");
        transferTargets(tokensV2);
        console.log("");
        console.log(" (stable assets - StableTokenV3)");
        transferTargets(tokensV3);
        console.log("");
        console.log(" (Broker / BiPoolManager / Reserve / SortedOracles)");
        transferTargets(core);
        console.log("");
        console.log(" (circuit breakers, ReserveTroveFactory)");
        transferTargets(singletons);
        console.log("");
        console.log(" (ReserveV2, liquidity strategies, FX price feeds, ChainlinkRelayerFactory)");
        transferTargets(v3Proxies);
        console.log("");
        console.log(" (CDP SystemParams / StabilityPool proxy admins)");
        transferTargets(cdpAdminOnly);

        console.log("");
        console.log(" > %d transactions in the Mento Governance proposal", governorTxCount);
        console.log(" > %d transactions in the migration multisig batch", safeTxCount);
    }

    function transferTargets(Target[] storage targets) internal {
        for (uint256 i = 0; i < targets.length; ++i) {
            Target storage t = targets[i];
            if (t.kind == Kind.CeloProxy) {
                transferCeloProxyAdmin(t);
                transferContractOwner(t);
            } else if (t.kind == Kind.OZTUP) {
                transferOZProxyAdmin(t);
                transferContractOwner(t);
            } else if (t.kind == Kind.OZTUPAdminOnly) {
                transferOZProxyAdmin(t);
            } else {
                transferContractOwner(t);
            }
        }
    }

    function transferCeloProxyAdmin(Target storage t) internal {
        address holder = ICeloProxy(t.addr)._getOwner();
        Senders.Sender storage s = senderFor(holder, t.name, "proxy admin");
        console.log("  > %s (%s) proxy admin: %s -> Celo Governance", t.name, t.addr, s.name);
        ICeloProxy(s.harness(t.addr))._transferOwnership(celoGovernance);
        count(s);
    }

    function transferOZProxyAdmin(Target storage t) internal {
        address proxyAdmin = getProxyAdmin(t.addr);
        address holder = IProxyAdminV5(proxyAdmin).owner();
        Senders.Sender storage s = senderFor(holder, t.name, "ProxyAdmin owner");
        console.log("  > %s (%s) ProxyAdmin owner: %s -> Celo Governance", t.name, t.addr, s.name);
        transferProxyAdminOwnership(s, t.addr, celoGovernance);
        count(s);
    }

    function transferContractOwner(Target storage t) internal {
        address holder = IOwnable(t.addr).owner();
        Senders.Sender storage s = senderFor(holder, t.name, "owner");
        console.log("  > %s (%s) owner: %s -> Celo Governance", t.name, t.addr, s.name);
        IOwnable(s.harness(t.addr)).transferOwnership(celoGovernance);
        count(s);
    }

    /// @dev Routes a right to the sender that currently holds it. Anything not held by the Mento
    ///      timelock or the migration multisig cannot be moved by this proposal and is a hard error.
    function senderFor(address holder, string memory name, string memory right)
        internal
        view
        returns (Senders.Sender storage)
    {
        if (holder == timelock) return sender("governor");
        if (holder == migrationSafe) return sender("migrationOwner");
        revert(string.concat(name, " ", right, " is held by neither the Mento timelock nor the migration multisig"));
    }

    function count(Senders.Sender storage s) internal {
        if (s.account == timelock) governorTxCount++;
        else safeTxCount++;
    }

    // ---------------------------------------------------------------------------------------------
    // Pre-checks
    // ---------------------------------------------------------------------------------------------

    function preChecks() internal view {
        console.log("== Pre-checks ==");
        console.log(" > Celo Governance:      %s", celoGovernance);
        console.log(" > Mento timelock:       %s", timelock);
        console.log(" > migration multisig:   %s", migrationSafe);
        console.log(
            unicode" > 👀 checking current holders of %d contracts",
            tokensV2.length + tokensV3.length + core.length + singletons.length + v3Proxies.length + cdpAdminOnly.length
        );

        checkHolders(tokensV2);
        checkHolders(tokensV3);
        checkHolders(core);
        checkHolders(singletons);
        checkHolders(v3Proxies);
        checkHolders(cdpAdminOnly);

        for (uint256 i = 0; i < tokensV2.length; ++i) {
            require(
                equalStrings(IERC20Metadata(tokensV2[i].addr).symbol(), tokensV2[i].name), "unexpected token symbol"
            );
        }
        for (uint256 i = 0; i < tokensV3.length; ++i) {
            require(
                equalStrings(IERC20Metadata(tokensV3[i].addr).symbol(), tokensV3[i].name), "unexpected token symbol"
            );
        }

        for (uint256 i = 0; i < guards.length; ++i) {
            require(guardHolder(guards[i]) == guards[i].expected, string.concat(guards[i].name, ": unexpected holder"));
        }
        console.log(unicode" > 🟢 every right is held by the Mento timelock or the migration multisig");

        address relayerFactory = lookupProxy("ChainlinkRelayerFactory", ProxyType.OZTUP);
        if (relayerFactory != address(0)) {
            console.log(
                unicode" > ⚠️  ChainlinkRelayerFactory ProxyAdmin owner is %s and is NOT moved by this proposal",
                IProxyAdminV5(getProxyAdmin(relayerFactory)).owner()
            );
        }
    }

    function checkHolders(Target[] storage targets) internal view {
        for (uint256 i = 0; i < targets.length; ++i) {
            Target storage t = targets[i];
            if (t.kind == Kind.CeloProxy) {
                senderFor(ICeloProxy(t.addr)._getOwner(), t.name, "proxy admin");
                senderFor(IOwnable(t.addr).owner(), t.name, "owner");
            } else if (t.kind == Kind.OZTUP) {
                senderFor(IProxyAdminV5(getProxyAdmin(t.addr)).owner(), t.name, "ProxyAdmin owner");
                senderFor(IOwnable(t.addr).owner(), t.name, "owner");
            } else if (t.kind == Kind.OZTUPAdminOnly) {
                senderFor(IProxyAdminV5(getProxyAdmin(t.addr)).owner(), t.name, "ProxyAdmin owner");
            } else {
                senderFor(IOwnable(t.addr).owner(), t.name, "owner");
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Post-checks
    // ---------------------------------------------------------------------------------------------

    function postChecks() internal {
        console.log("");
        console.log("== Post-checks ==");

        console.log(" (ownership transfers)");
        checkTransferred(tokensV2);
        checkTransferred(tokensV3);
        checkTransferred(core);
        checkTransferred(singletons);
        checkTransferred(v3Proxies);
        checkTransferred(cdpAdminOnly);

        console.log("");
        console.log(" (out-of-scope contracts untouched)");
        for (uint256 i = 0; i < guards.length; ++i) {
            require(guardHolder(guards[i]) == guards[i].expected, string.concat(guards[i].name, ": holder changed"));
            console.log(unicode"  > 🟢 %s unchanged", guards[i].name);
        }

        checkStableTokenPermissions();
        checkCorePermissions();
        checkOraclePermissions();
        checkV3Permissions();

        if (dependsOnProposalId != 0) {
            checkDependencyGuard(sender("governor").ozGovernor().governor);
        }
    }

    function checkTransferred(Target[] storage targets) internal view {
        for (uint256 i = 0; i < targets.length; ++i) {
            Target storage t = targets[i];
            if (t.kind == Kind.CeloProxy) {
                require(ICeloProxy(t.addr)._getOwner() == celoGovernance, string.concat(t.name, ": proxy admin"));
                require(IOwnable(t.addr).owner() == celoGovernance, string.concat(t.name, ": owner"));
                console.log(unicode"  > 🟢 %s proxy admin and owner transferred", t.name);
            } else if (t.kind == Kind.OZTUP) {
                require(
                    IProxyAdminV5(getProxyAdmin(t.addr)).owner() == celoGovernance,
                    string.concat(t.name, ": ProxyAdmin owner")
                );
                require(IOwnable(t.addr).owner() == celoGovernance, string.concat(t.name, ": owner"));
                console.log(unicode"  > 🟢 %s ProxyAdmin owner and owner transferred", t.name);
            } else if (t.kind == Kind.OZTUPAdminOnly) {
                require(
                    IProxyAdminV5(getProxyAdmin(t.addr)).owner() == celoGovernance,
                    string.concat(t.name, ": ProxyAdmin owner")
                );
                console.log(unicode"  > 🟢 %s ProxyAdmin owner transferred", t.name);
            } else {
                require(IOwnable(t.addr).owner() == celoGovernance, string.concat(t.name, ": owner"));
                console.log(unicode"  > 🟢 %s owner transferred", t.name);
            }
        }
    }

    function checkStableTokenPermissions() internal {
        console.log("");
        console.log(" (permissions on stable assets)");

        for (uint256 i = 0; i < tokensV2.length; ++i) {
            address token = tokensV2[i].addr;
            // proxy admin: re-point the proxy at its current implementation
            address impl = ICeloProxy(token)._getImplementation();
            vm.prank(celoGovernance);
            ICeloProxy(token)._setImplementation(impl);
            require(ICeloProxy(token)._getImplementation() == impl, "failed to set implementation");
            // owner: (re)set the broker
            address broker = IStableTokenV2Admin(token).broker();
            vm.prank(celoGovernance);
            IStableTokenV2Admin(token).setBroker(broker);
            require(IStableTokenV2Admin(token).broker() == broker, "failed to set broker");
            console.log(unicode"  > 🟢 Celo Governance can upgrade %s and set its broker", tokensV2[i].name);
        }

        for (uint256 i = 0; i < tokensV3.length; ++i) {
            address token = tokensV3[i].addr;
            address impl = ICeloProxy(token)._getImplementation();
            vm.prank(celoGovernance);
            ICeloProxy(token)._setImplementation(impl);
            require(ICeloProxy(token)._getImplementation() == impl, "failed to set implementation");
            // owner: grant + revoke a minter role
            address probe = address(1337);
            vm.prank(celoGovernance);
            IStableTokenV3(token).setMinter(probe, true);
            require(IStableTokenV3(token).isMinter(probe), "failed to set minter");
            vm.prank(celoGovernance);
            IStableTokenV3(token).setMinter(probe, false);
            require(!IStableTokenV3(token).isMinter(probe), "failed to unset minter");
            console.log(unicode"  > 🟢 Celo Governance can upgrade %s and manage its minters", tokensV3[i].name);
        }
    }

    function checkCorePermissions() internal {
        console.log("");
        console.log(" (permissions on Broker / BiPoolManager / Reserve)");

        address broker = getTarget(core, "Broker").addr;
        address biPoolManager = getTarget(core, "BiPoolManager").addr;
        address reserve = getTarget(core, "Reserve").addr;

        // Broker: re-set its reserve
        require(IBrokerAdminView(broker).reserve() == reserve, "Broker reserve is not the Reserve proxy");
        vm.prank(celoGovernance);
        IBrokerAdminView(broker).setReserve(reserve);
        require(IBrokerAdminView(broker).reserve() == reserve, "failed to set reserve on Broker");
        console.log(unicode"  > 🟢 Celo Governance can configure the Broker");

        // BiPoolManager: re-set the broker
        vm.prank(celoGovernance);
        IBiPoolManager(biPoolManager).setBroker(broker);
        require(IBiPoolManager(biPoolManager).broker() == broker, "failed to set broker on BiPoolManager");
        console.log(unicode"  > 🟢 Celo Governance can configure the BiPoolManager");

        // Reserve: re-set the daily spending ratio
        uint256 ratio = IReserve(reserve).getDailySpendingRatio();
        vm.prank(celoGovernance);
        IReserve(reserve).setDailySpendingRatio(ratio);
        require(IReserve(reserve).getDailySpendingRatio() == ratio, "failed to set daily spending ratio");
        console.log(unicode"  > 🟢 Celo Governance can configure the Reserve");
    }

    function checkOraclePermissions() internal {
        console.log("");
        console.log(" (permissions on the oracle layer)");

        address sortedOracles = getTarget(core, "SortedOracles").addr;
        address breakerBox = getTarget(singletons, "BreakerBox").addr;
        address medianDeltaBreaker = getTarget(singletons, "MedianDeltaBreaker").addr;
        address valueDeltaBreaker = getTarget(singletons, "ValueDeltaBreaker").addr;
        address relayerFactory = getTarget(v3Proxies, "ChainlinkRelayerFactory").addr;

        address sampleFeed = address(uint160(uint256(keccak256("mgp19.sampleFeed"))));

        require(ISortedOracles(sortedOracles).getOracles(sampleFeed).length == 0, "sample feed should have no oracles");
        vm.prank(celoGovernance);
        ISortedOracles(sortedOracles).addOracle(sampleFeed, address(1337));
        require(ISortedOracles(sortedOracles).getOracles(sampleFeed).length == 1, "failed to add oracle");
        console.log(unicode"  > 🟢 Celo Governance can whitelist oracles on SortedOracles");

        require(!IBreakerBox(breakerBox).isBreaker(address(1337)), "probe breaker should not exist");
        vm.prank(celoGovernance);
        IBreakerBox(breakerBox).addBreaker(address(1337), 1);
        require(IBreakerBox(breakerBox).isBreaker(address(1337)), "failed to add breaker");
        console.log(unicode"  > 🟢 Celo Governance can add breakers on BreakerBox");

        vm.prank(celoGovernance);
        IMedianDeltaBreaker(medianDeltaBreaker).setSmoothingFactor(sampleFeed, 1e18);
        require(IMedianDeltaBreaker(medianDeltaBreaker).getSmoothingFactor(sampleFeed) == 1e18, "smoothing factor");
        console.log(unicode"  > 🟢 Celo Governance can configure the MedianDeltaBreaker");

        address[] memory feeds = new address[](1);
        uint256[] memory values = new uint256[](1);
        feeds[0] = sampleFeed;
        values[0] = 1e12;
        vm.prank(celoGovernance);
        IValueDeltaBreaker(valueDeltaBreaker).setReferenceValues(feeds, values);
        require(IValueDeltaBreaker(valueDeltaBreaker).referenceValues(sampleFeed) == 1e12, "reference value");
        console.log(unicode"  > 🟢 Celo Governance can configure the ValueDeltaBreaker");

        address relayerDeployer = IChainlinkRelayerFactoryAdmin(relayerFactory).relayerDeployer();
        vm.prank(celoGovernance);
        IChainlinkRelayerFactoryAdmin(relayerFactory).setRelayerDeployer(relayerDeployer);
        console.log(unicode"  > 🟢 Celo Governance can configure the ChainlinkRelayerFactory");
    }

    function checkV3Permissions() internal {
        console.log("");
        console.log(" (permissions on V3 reserve issuance and CDP branches)");

        // Ownable contracts behind OZ proxies: a no-op transferOwnership proves onlyOwner access.
        for (uint256 i = 0; i < v3Proxies.length; ++i) {
            vm.prank(celoGovernance);
            IOwnable(v3Proxies[i].addr).transferOwnership(celoGovernance);
            require(IOwnable(v3Proxies[i].addr).owner() == celoGovernance, "owner check");
        }
        vm.prank(celoGovernance);
        IOwnable(getTarget(singletons, "ReserveTroveFactory").addr).transferOwnership(celoGovernance);
        console.log(unicode"  > 🟢 Celo Governance holds the owner role on all V3 issuance contracts");

        // ProxyAdmins: upgrade every proxy to its current implementation.
        // (ChainlinkRelayerFactory is Kind.Ownable here: its ProxyAdmin is owned by a legacy Safe, see mgp19.md)
        for (uint256 i = 0; i < v3Proxies.length; ++i) {
            if (v3Proxies[i].kind != Kind.OZTUP) continue;
            upgradeToSelf(v3Proxies[i]);
        }
        for (uint256 i = 0; i < cdpAdminOnly.length; ++i) {
            upgradeToSelf(cdpAdminOnly[i]);
        }
        console.log(unicode"  > 🟢 Celo Governance can upgrade all V3 issuance and CDP proxies");
    }

    function upgradeToSelf(Target storage t) internal {
        address proxyAdmin = getProxyAdmin(t.addr);
        address impl = getOZTUPProxyImplementation(t.addr);
        vm.prank(celoGovernance);
        IProxyAdminV5(proxyAdmin).upgradeAndCall(t.addr, impl, "");
        require(getOZTUPProxyImplementation(t.addr) == impl, string.concat(t.name, ": upgrade failed"));
    }

    // ---------------------------------------------------------------------------------------------
    // Guards: out-of-scope rights that must not move
    // ---------------------------------------------------------------------------------------------

    function setUpGuards() internal {
        // Mento DAO
        guards.push(Guard("Mento ProxyAdmin (governance proxies) owner", lookupOrFail("ProxyAdmin"), false, timelock));
        guards.push(Guard("Locking owner", lookupProxyOrFail("Locking", ProxyType.OZTUP), false, timelock));
        guards.push(
            Guard("MentoGovernor proxy admin", lookupProxyOrFail("MentoGovernor", ProxyType.OZTUP), true, timelock)
        );
        // Mento FX DEX (owner stays with the migration multisig for now)
        addDexGuard("FPMMFactory");
        addDexGuard("FactoryRegistry");
        addDexGuard("OpenLiquidityStrategy");
        addDexGuard("OracleAdapter");
        addDexGuard("OracleAdapterCollateral");
        address virtualPoolFactory = lookup("VirtualPoolFactory:v3.0.0");
        if (virtualPoolFactory != address(0)) {
            guards.push(Guard("VirtualPoolFactory owner", virtualPoolFactory, false, migrationSafe));
        }
        address marketHoursBreaker = lookup("MarketHoursBreakerToggleable:v3.0.0");
        if (marketHoursBreaker != address(0)) {
            guards.push(Guard("MarketHoursBreakerToggleable owner", marketHoursBreaker, false, migrationSafe));
        }
    }

    function addDexGuard(string memory name) internal {
        address proxy = lookupProxy(name, ProxyType.OZTUP);
        if (proxy == address(0)) {
            require(block.chainid != CELO_MAINNET_CHAIN_ID, string.concat(name, " not deployed"));
            return;
        }
        guards.push(Guard(string.concat(name, " owner"), proxy, false, migrationSafe));
        guards.push(Guard(string.concat(name, " ProxyAdmin owner"), proxy, true, migrationSafe));
    }

    function guardHolder(Guard storage g) internal view returns (address) {
        if (!g.proxyAdminRight) return IOwnable(g.addr).owner();
        address proxyAdmin = getProxyAdmin(g.addr);
        return IProxyAdminV5(proxyAdmin).owner();
    }

    // ---------------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------------

    function addCeloProxy(Target[] storage list, string memory name) internal {
        address addr = lookupProxy(name, ProxyType.CELO);
        if (!found(addr, name)) return;
        list.push(Target(name, addr, Kind.CeloProxy));
    }

    function addOZTUP(Target[] storage list, string memory name, Kind kind) internal {
        address addr = lookupProxy(name, ProxyType.OZTUP);
        if (!found(addr, name)) return;
        list.push(Target(name, addr, kind));
    }

    function addOwnable(Target[] storage list, string memory name, string memory identifier) internal {
        address addr = lookup(identifier);
        if (!found(addr, name)) return;
        list.push(Target(name, addr, Kind.Ownable));
    }

    /// @dev On mainnet every contract must exist; on testnets a missing contract is skipped with a log.
    function found(address addr, string memory name) internal view returns (bool) {
        if (addr != address(0)) return true;
        require(block.chainid != CELO_MAINNET_CHAIN_ID, string.concat(name, " not deployed"));
        console.log(unicode" > ⚠️  %s not deployed on this network, skipping", name);
        return false;
    }

    function getTarget(Target[] storage list, string memory name) internal view returns (Target storage) {
        for (uint256 i = 0; i < list.length; ++i) {
            if (equalStrings(list[i].name, name)) return list[i];
        }
        revert(string.concat(name, " not in target list"));
    }

    function equalStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
