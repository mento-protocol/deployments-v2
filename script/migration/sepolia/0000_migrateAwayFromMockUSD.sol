// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {IPricingModule} from "lib/mento-core/contracts/interfaces/IPricingModule.sol";
import {IExchangeProvider} from "lib/mento-core/contracts/interfaces/IExchangeProvider.sol";

import {FixidityLib} from "@celo/common/FixidityLib.sol";

import {ProxyHelper} from "../../helpers/ProxyHelper.sol";

contract MigrateAwayFromMockUSD is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address cUSD;
    address mockUsdc;
    address mockUsdt;

    /// @custom:senders deployer
    /// @custom:env {bytes32:optional} exchangeId
    function run() public virtual broadcast {
        Senders.Sender storage deployer = sender("deployer");

        cUSD = lookupProxyOrFail("cUSD");
        mockUsdc = lookupOrFail("MockERC20:USDC");
        mockUsdt = lookupOrFail("MockERC20:USDT");

        IReserve reserve = IReserve(lookupProxyOrFail("Reserve"));
        IBiPoolManager biPoolManager = IBiPoolManager(lookupProxyOrFail("BiPoolManager"));

        require(reserve.isCollateralAsset(mockUsdc));
        require(reserve.isCollateralAsset(mockUsdt));

        (bytes32 usdtExchangeId, uint256 usdtExchangeIdIndex) = getExchangeId(cUSD, mockUsdt);
        (bytes32 usdcExchangeId, uint256 usdcExchangeIdIndex) = getExchangeId(cUSD, mockUsdc);

        require(usdtExchangeId != bytes32(0));
        require(usdcExchangeId != bytes32(0));

        console.logBytes32(usdtExchangeId);
        console.logBytes32(usdcExchangeId);
    }

    function getExchangeId(address asset0, address asset1) public view returns (bytes32, uint256) {
        IBiPoolManager biPoolManager = IBiPoolManager(lookupProxyOrFail("BiPoolManager"));
        IExchangeProvider.Exchange[] memory exchanges = biPoolManager.getExchanges();
        for (uint256 i = exchanges.length - 1; i >= 0; i--) {
            IExchangeProvider.Exchange memory exchange = exchanges[i];
            if (exchange.assets[0] == asset0 && exchange.assets[1] == asset1 || exchange.assets[0] == asset1 && exchange.assets[1] == asset0) {
                return (exchange.exchangeId, i);
            }
            if (i == 0) break;
        }

        return (bytes32(0), 0);
    }
}
