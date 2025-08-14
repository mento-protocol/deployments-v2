// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IPricingModule} from "lib/mento-core/contracts/interfaces/IPricingModule.sol";
import {FixidityLib} from "@celo/common/FixidityLib.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract CreateExchangePools is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();

        Senders.Sender storage deployer = sender("deployer");

        address biPoolManagerAddy = lookupProxyOrFail("BiPoolManager");
        address brokerAddy = lookupProxyOrFail("Broker");

        IBroker broker = IBroker(deployer.harness(brokerAddy));

        IBiPoolManager biPoolManager = IBiPoolManager(
            deployer.harness(biPoolManagerAddy)
        );

        // Create pools for all stable tokens
        IMentoConfig.ExchangeConfig[] memory exchanges = config.getExchanges();

        for (uint256 i = 0; i < exchanges.length; i++) {
            IMentoConfig.ExchangeConfig memory exchange = exchanges[i];
            bytes32 exchangeId = biPoolManager.createExchange(exchange.pool);

            if (exchanges[i].tradingLimits.asset0.flags != 0) {
                broker.configureTradingLimit(
                    exchangeId,
                    exchange.pool.asset0,
                    exchange.tradingLimits.asset0
                );
            }
            if (exchanges[i].tradingLimits.asset1.flags != 0) {
                broker.configureTradingLimit(
                    exchangeId,
                    exchange.pool.asset1,
                    exchange.tradingLimits.asset1
                );
            }

            console.log("Created exchange pool:");
            console.log("  exchangeId:", uint256(exchangeId));
            console.log("  asset0:", exchanges[i].pool.asset0);
            console.log("  asset1:", exchanges[i].pool.asset1);
        }
    }
}

