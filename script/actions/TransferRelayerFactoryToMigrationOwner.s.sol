// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

/// @dev Minimal interface for the ChainlinkRelayerFactory admin functions we need.
///      IChainlinkRelayerFactory does not expose the OwnableUpgradeable functions.
interface IChainlinkRelayerFactoryAdmin {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function relayerDeployer() external view returns (address);
    function setRelayerDeployer(address newRelayerDeployer) external;
}

/// @notice Hands the ChainlinkRelayerFactory over to the MigrationMultisig: sets the
///         relayer deployer to the migration owner and transfers ownership to it, so the
///         migration owner can both deploy relayers and wire them into SortedOracles.
/// @dev The factory's current owner is provided as the `ChainlinkRelayerFactoryOwner`
///      sender (used as the harness). setRelayerDeployer is onlyOwner, so it must run
///      before transferOwnership while the current owner still holds ownership.
contract TransferRelayerFactoryToMigrationOwner is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address factory;

    function setUp() public {
        factory = lookupProxyOrFail("ChainlinkRelayerFactory", ProxyType.OZTUP);
    }

    /// @custom:senders chainlinkRelayerFactoryOwner, migrationOwner
    function run() public broadcast {
        Senders.Sender storage currentOwner = sender("chainlinkRelayerFactoryOwner");
        address migrationOwner = sender("migrationOwner").account;

        IChainlinkRelayerFactoryAdmin factoryRead = IChainlinkRelayerFactoryAdmin(factory);
        IChainlinkRelayerFactoryAdmin factoryWrite = IChainlinkRelayerFactoryAdmin(currentOwner.harness(factory));

        console.log("\n===== Transfer ChainlinkRelayerFactory to migration owner =====");
        console.log("Factory:           ", factory);
        console.log("Current owner:     ", factoryRead.owner());
        console.log("Current deployer:  ", factoryRead.relayerDeployer());
        console.log("Migration owner:   ", migrationOwner);

        require(
            factoryRead.owner() == currentOwner.account,
            "ChainlinkRelayerFactoryOwner sender is not the current factory owner"
        );

        // 1. Point the relayer deployer at the migration owner (onlyOwner, so do it first).
        if (factoryRead.relayerDeployer() != migrationOwner) {
            factoryWrite.setRelayerDeployer(migrationOwner);
            console.log("  Set relayerDeployer ->", migrationOwner);
        } else {
            console.log("  relayerDeployer already set to migration owner, skipping");
        }

        // 2. Transfer ownership to the migration owner.
        if (factoryRead.owner() != migrationOwner) {
            factoryWrite.transferOwnership(migrationOwner);
            console.log("  Transferred ownership ->", migrationOwner);
        } else {
            console.log("  ownership already held by migration owner, skipping");
        }

        _verify(migrationOwner);
    }

    function _verify(address migrationOwner) internal view {
        console.log("\n===== Verification =====");

        IChainlinkRelayerFactoryAdmin factoryRead = IChainlinkRelayerFactoryAdmin(factory);
        address newOwner = factoryRead.owner();
        address newDeployer = factoryRead.relayerDeployer();

        console.log("  owner:          ", newOwner);
        console.log("  relayerDeployer:", newDeployer);

        require(newOwner == migrationOwner, "Verify: factory owner is not migration owner");
        require(newDeployer == migrationOwner, "Verify: relayerDeployer is not migration owner");

        console.log("\n  ChainlinkRelayerFactory owner & relayerDeployer set to migration owner");
    }
}
