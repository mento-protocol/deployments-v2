// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IPricingModule} from "lib/mento-core/contracts/interfaces/IPricingModule.sol";
import {IExchangeProvider} from "lib/mento-core/contracts/interfaces/IExchangeProvider.sol";

import {FixidityLib} from "@celo/common/FixidityLib.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract DestroyExchangePools is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    /// @custom:env {bytes32:optional} exchangeId
    function run() public virtual broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address biPoolManagerAddy = lookupProxyOrFail("BiPoolManager");
        bytes32 pickedExchangeId = vm.envOr("exchangeId", bytes32(0));

        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManagerAddy);
        IBiPoolManager biPoolManager = IBiPoolManager(
            deployer.harness(biPoolManagerAddy)
        );

        IExchangeProvider.Exchange[] memory exchanges = biPoolManagerRead
            .getExchanges();

        for (uint256 i = exchanges.length; i > 0; i--) {
            IExchangeProvider.Exchange memory exchange = exchanges[i - 1];
            if (
                pickedExchangeId != bytes32(0) &&
                exchange.exchangeId != pickedExchangeId
            ) continue;
            biPoolManager.destroyExchange(exchange.exchangeId, i - 1);

            console.log("Destroyed exchange pool:");
            console.log("  exchangeId:", uint256(exchange.exchangeId));
            console.log("  asset0:", exchange.assets[0]);
            console.log("  asset1:", exchange.assets[1]);
        }
    }
}
