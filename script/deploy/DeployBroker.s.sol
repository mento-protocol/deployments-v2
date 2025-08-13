// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

// Import proxy contract
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Interface for Broker initialization
interface IBroker {
    function initialize(
        address[] calldata _exchangeProviders,
        address[] calldata _reserves
    ) external;
}

contract DeployBroker is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    // Constant for proxy artifact path
    string constant PROXY_ARTIFACT =
        "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";

    address brokerImpl;
    address brokerProxy;

    /**
     * @custom:senders deployer
     */
    function run() public broadcast {
        // Get the sender
        Senders.Sender storage deployer = sender("deployer");

        // Get the ProxyAdmin address (should be deployed already)
        address proxyAdmin = lookup("ProxyAdmin");
        require(proxyAdmin != address(0), "ProxyAdmin not deployed");

        // Step 1: Deploy Broker implementation (0.8.18)
        brokerImpl = deployer
            .create3("lib/mento-core/contracts/swap/Broker.sol:Broker")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false)); // test parameter
        console.log("Broker implementation deployed at:", brokerImpl);

        // Step 2: Prepare initialization data
        // For now, initialize with empty arrays - exchange providers and reserves can be added later
        address[] memory exchangeProviders = new address[](0);
        address[] memory reserves = new address[](0);

        bytes memory initData = abi.encodeWithSelector(
            IBroker.initialize.selector,
            exchangeProviders, // empty exchange providers array
            reserves // empty reserves array
        );

        // Step 3: Deploy proxy with initialization
        brokerProxy = deployer
            .create3(PROXY_ARTIFACT)
            .setLabel("Broker")
            .deploy(
                abi.encode(
                    brokerImpl, // implementation address
                    proxyAdmin, // admin address
                    initData // initialization data
                )
            );
        console.log("Broker proxy deployed at:", brokerProxy);

        // Step 4: Verify deployment
        console.log("Broker deployment completed:");
        console.log("- Implementation:", brokerImpl);
        console.log("- Proxy:", brokerProxy);
        console.log("- ProxyAdmin:", proxyAdmin);

        // Note: Exchange providers and reserves can be added later via:
        // IBroker(brokerProxy).addExchangeProvider(provider, reserve)
    }
}

