// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract ConfigureBrokerExchangeProviders is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address brokerProxy = lookupProxyOrFail("Broker");
        address biPoolManagerProxy = lookupProxyOrFail("BiPoolManager");
        address reserveProxy = lookupProxyOrFail("Reserve");

        IBroker broker = IBroker(deployer.harness(brokerProxy));

        broker.addExchangeProvider(biPoolManagerProxy, reserveProxy);
        console.log("Added BiPoolManager as exchange provider");
    }
}

