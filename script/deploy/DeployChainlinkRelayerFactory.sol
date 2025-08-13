// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";

contract DeployChainlinkRelayerFactory is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address chainlinkRelayerFactoryImpl;
    address chainlinkRelayerFactoryProxy;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // Deploy implementation
        chainlinkRelayerFactoryImpl = deployer
            .create3("ChainlinkRelayerFactory")
            .setLabel("v2.6.5")
            .deploy(abi.encode(true));

        // Get ProxyAdmin
        address proxyAdmin = lookup("ProxyAdmin");
        require(proxyAdmin != address(0), "ProxyAdmin not deployed");

        // Deploy proxy
        chainlinkRelayerFactoryProxy = deployer
            .create3("TransparentUpgradeableProxy")
            .setLabel("ChainlinkRelayerFactory")
            .deploy(
                abi.encode(
                    chainlinkRelayerFactoryImpl,
                    proxyAdmin,
                    abi.encodeWithSelector(
                        IChainlinkRelayerFactory.initialize.selector,
                        lookup("TransparentUpgradeableProxy:SortedOracles"),
                        deployer.account
                    )
                )
            );

        console.log(
            "ChainlinkRelayerFactory implementation:",
            chainlinkRelayerFactoryImpl
        );
        console.log(
            "ChainlinkRelayerFactory proxy:",
            chainlinkRelayerFactoryProxy
        );
    }
}
