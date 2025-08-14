// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";

contract DeployChainlinkRelayerFactory is TrebScript, ProxyHelper {
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

        address sortedOracles = lookupProxyOrFail("SortedOracles");

        // Deploy proxy
        chainlinkRelayerFactoryProxy = deployProxy(
            ProxyType.OZTUP,
            deployer,
            "ChainlinkRelayerFactory",
            chainlinkRelayerFactoryImpl,
            abi.encodeWithSelector(
                IChainlinkRelayerFactory.initialize.selector,
                sortedOracles,
                deployer.account
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
