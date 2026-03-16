// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @title TransferProxyAdminOwnership
/// @notice Transfers the ProxyAdmin ownership of a proxy contract to the MigrationMultisig.
/// @dev Set the proxyName env variable to the name of the proxy contract (e.g. "OpenLiquidityStrategy").
contract TransferProxyAdminOwnership is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;

    /// @custom:senders deployer, migrationOwner
    /// @custom:env {string} proxyName - The name of the proxy contract to transfer ownership of
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage migrationOwner = sender("migrationOwner");

        string memory proxyName = vm.envString("proxyName");
        address proxy = lookupProxyOrFail(proxyName);

        require(migrationOwner.account != address(0), "MigrationOwner not found");

        address proxyAdmin = getProxyAdmin(proxy);
        address ownerBefore = IOwnable(proxyAdmin).owner();

        console.log("Proxy:          ", proxy);
        console.log("ProxyAdmin:     ", proxyAdmin);
        console.log("Owner (before): ", ownerBefore);
        console.log("Owner (after):  ", migrationOwner.account);

        // Transfer ProxyAdmin ownership from deployer to migrationOwner
        IOwnable(deployer.harness(proxyAdmin)).transferOwnership(migrationOwner.account);

        // Verify
        require(
            IOwnable(proxyAdmin).owner() == migrationOwner.account,
            string.concat(proxyName, " ProxyAdmin ownership transfer failed")
        );
        console.log("Ownership transferred successfully");
    }
}
