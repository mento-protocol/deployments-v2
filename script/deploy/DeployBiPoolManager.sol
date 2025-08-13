// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";

contract DeployBiPoolManager is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address biPoolManagerImpl;
    address biPoolManagerProxy;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        deployBiPoolManager(deployer);
        initializeBiPoolManager(deployer);
    }

    function deployBiPoolManager(Senders.Sender storage deployer) internal {
        // Phase 1: Deploy BiPoolManager implementation
        biPoolManagerImpl = deployer
            .create3("BiPoolManager")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false));

        // Phase 2: Deploy proxy without initialization
        address proxyAdmin = lookup("ProxyAdmin");

        biPoolManagerProxy = deployer
            .create3("TransparentUpgradeableProxy")
            .setLabel("BiPoolManager")
            .deploy(abi.encode(biPoolManagerImpl, proxyAdmin, ""));
    }

    function initializeBiPoolManager(Senders.Sender storage deployer) internal {
        // Phase 3: Initialize BiPoolManager through harness
        address brokerProxy = lookup("TransparentUpgradeableProxy:Broker");
        address reserveProxy = lookup("TransparentUpgradeableProxy:Reserve");
        address sortedOraclesProxy = lookup(
            "TransparentUpgradeableProxy:SortedOracles"
        );
        address breakerBoxProxy = lookup("BreakerBox:v2.6.5");

        IBiPoolManager biPoolManager = IBiPoolManager(
            deployer.harness(biPoolManagerProxy)
        );
        biPoolManager.initialize(
            brokerProxy,
            IReserve(reserveProxy),
            ISortedOracles(sortedOraclesProxy),
            IBreakerBox(breakerBoxProxy)
        );
    }
}
