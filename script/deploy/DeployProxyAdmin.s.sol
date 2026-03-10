// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

/**
 * @title DeployProxyAdmin
 * @notice Deployment script for ProxyAdmin contract
 * @dev Generated automatically by treb
 */
contract DeployProxyAdmin is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage migrationOwner = sender("migrationOwner");
        deployer.create3("ProxyAdmin").deploy(abi.encode(migrationOwner.account));
    }
}
