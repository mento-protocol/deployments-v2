// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

/**
 * @title DeployProxyAdmin
 * @notice Deployment script for ProxyAdmin contract
 * @dev Generated automatically by treb
 */
contract DeployProxyAdmin is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage migrationOwner = sender("migrationOwner");
        address proxyAdmin = deployer.create3("ProxyAdmin").deploy(abi.encode(migrationOwner.account));

        // ============== Verify contract ownership =================
        address migrationMultisig = lookupOrFail("MigrationMultisig");

        require(IOwnable(proxyAdmin).owner() == migrationMultisig);
        console.log(unicode"ProxyAdmin owned by migration multisig ✅");

    }
}
