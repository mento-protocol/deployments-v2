// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";

contract MGP17 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    address internal biPoolManagerProxy;
    address internal newImplementation;
    address internal timelockProxy;

    function setUp() public {
        biPoolManagerProxy = lookupProxyOrFail("BiPoolManager", ProxyType.CELO);
        newImplementation = lookupWithCodeOrFail("BiPoolManagerFeeSetter");
        timelockProxy = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
    }

    /// @custom:senders deployer, governor
    function run() public virtual broadcast {
        Senders.Sender storage govSender = sender("governor");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-17: Upgrade BiPoolManager with FeeSetter");
        ozGovSender.setProposalDescription("./mgps/mgp17.md");

        preChecks();

        upgradeImplementation(govSender);

        postChecks();
    }

    function upgradeImplementation(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Upgrading BiPoolManager implementation ==");
        console.log(" > BiPoolManager proxy: %s", biPoolManagerProxy);
        console.log(" > New implementation:  %s", newImplementation);

        ICeloProxy(govSender.harness(biPoolManagerProxy))._setImplementation(newImplementation);
    }

    /// =========== Proposal checks ===========

    function preChecks() internal view {
        console.log("== Pre-checks ==");
        console.log(unicode" > 👀 checking BiPoolManager proxy admin is governance timelock");

        require(
            ICeloProxy(biPoolManagerProxy)._getOwner() == timelockProxy,
            "BiPoolManager proxy admin is not governance timelock"
        );
    }

    function postChecks() internal {
        console.log("");
        console.log("== Post-checks ==");

        require(
            ICeloProxy(biPoolManagerProxy)._getImplementation() == newImplementation,
            "BiPoolManager implementation was not upgraded"
        );
        console.log(unicode"  > 🟢 BiPoolManager implementation upgraded successfully");

        checkSetSpreadPermission();
    }

    function checkSetSpreadPermission() internal {
        console.log("");
        console.log(" (permissions on BiPoolManager setSpread)");

        address owner = IOwnable(biPoolManagerProxy).owner();
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
        require(exchangeIds.length > 0, "no exchanges found on BiPoolManager");

        bytes32 exchangeId = exchangeIds[0];
        IBiPoolManager.PoolExchange memory exchange = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
        uint256 originalSpread = exchange.config.spread.value;

        // Set a test spread value
        uint256 testSpread = originalSpread == 0 ? 1 : originalSpread - 1;
        vm.prank(owner);
        IBiPoolManager(biPoolManagerProxy).setSpread(exchangeId, testSpread);

        exchange = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
        require(exchange.config.spread.value == testSpread, "failed to set spread");

        // Restore original spread
        vm.prank(owner);
        IBiPoolManager(biPoolManagerProxy).setSpread(exchangeId, originalSpread);

        exchange = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
        require(exchange.config.spread.value == originalSpread, "failed to restore spread");

        console.log(unicode"  > 🟢 owner can set spread on BiPoolManager");
    }
}
