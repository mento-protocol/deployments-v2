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
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";

import {FixidityLib} from "@celo/common/FixidityLib.sol";

import {ProxyHelper} from "../../helpers/ProxyHelper.sol";

interface IBrokerWithLimits is IBroker {
    function tradingLimitsConfig(bytes32) external view returns (ITradingLimits.Config memory);
}

contract MigrateAwayFromMockUSD is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    error ExchangeNotFound();

    address internal constant USDT = 0xd077A400968890Eacc75cdc901F0356c943e4fDb;
    address internal constant USDC = 0x01C5C0122039549AD1493B8220cABEdD739BC44E;

    uint256 internal exchangesBefore;
    address internal cUSD;
    address internal mockUsdc;
    address internal mockUsdt;
    IReserve internal reserve;
    IBiPoolManager internal biPoolManager;
    IBrokerWithLimits internal broker;

    IReserve internal reserveWrite;
    IBiPoolManager internal biPoolManagerWrite;
    IBrokerWithLimits internal brokerWrite;

    function setup() public {
        Senders.Sender storage deployer = sender("deployer");

        reserve = IReserve(lookupProxyOrFail("Reserve"));
        biPoolManager = IBiPoolManager(lookupProxyOrFail("BiPoolManager"));
        broker = IBrokerWithLimits(lookupProxyOrFail("Broker"));

        reserveWrite = IReserve(deployer.harness(lookupProxyOrFail("Reserve")));
        biPoolManagerWrite = IBiPoolManager(deployer.harness(lookupProxyOrFail("BiPoolManager")));
        brokerWrite = IBrokerWithLimits(deployer.harness(lookupProxyOrFail("Broker")));

        cUSD = lookupProxyOrFail("cUSD");
        mockUsdc = lookupOrFail("MockERC20:USDC");
        mockUsdt = lookupOrFail("MockERC20:USDT");
        exchangesBefore = biPoolManager.getExchanges().length;
    }

    function preChecks() internal view {
        require(!reserve.isCollateralAsset(USDC), "pre: USDC is already a collateral");
        require(!reserve.isCollateralAsset(USDT), "pre: USDT is already a collateral");
        require(reserve.collateralAssets(0) == mockUsdc, "pre: Mock USDC is not collateral asset 0");
        require(reserve.collateralAssets(1) == mockUsdt, "pre: Mock USDT is not collateral asset 1");
    }

    function postChecks() internal view {
        require(!reserve.isCollateralAsset(mockUsdc), "post: Mock USDC is still a collateral");
        require(!reserve.isCollateralAsset(mockUsdt), "post: Mock USDT is still a collateral");

        require(reserve.isCollateralAsset(USDC), "post: USDC is still not a collateral");
        require(reserve.isCollateralAsset(USDT), "post: USDT is still not a collateral");

        require(biPoolManager.getExchanges().length == exchangesBefore, "post: Exchanges length mismatch after");

        console.log(unicode"✅ Post checks passed 🎉 ");
    }

    /// @custom:senders deployer
    function run() public virtual broadcast {
        setup();

        preChecks();

        console.log(unicode"🫡 Removing mock USDT and USDC as collateral");
        reserveWrite.removeCollateralAsset(mockUsdt, 1);
        reserveWrite.removeCollateralAsset(mockUsdc, 0);

        console.log(unicode"🤝 Adding USDC and USDT as collateral");
        reserveWrite.addCollateralAsset(USDC);
        reserveWrite.addCollateralAsset(USDT);

        (IBiPoolManager.PoolExchange memory usdtExchange, uint256 usdtExchangeIdIndex, bytes32 usdtExchangeId) =
            getExchange(cUSD, mockUsdt);
        (IBiPoolManager.PoolExchange memory usdcExchange, uint256 usdcExchangeIdIndex, bytes32 usdcExchangeId) =
            getExchange(cUSD, mockUsdc);

        require(usdtExchangeId != bytes32(0), "USDT Exchange not found");
        require(usdcExchangeId != bytes32(0), "USDC Exchange not found");

        bytes32 usdtLimitId = usdtExchangeId ^ bytes32(uint256(uint160(cUSD)));
        bytes32 usdcLimitId = usdcExchangeId ^ bytes32(uint256(uint160(cUSD)));

        ITradingLimits.Config memory usdtLimit = broker.tradingLimitsConfig(usdtLimitId);
        ITradingLimits.Config memory usdcLimit = broker.tradingLimitsConfig(usdcLimitId);

        require(usdtExchange.asset0 == cUSD, "cUSD is not asset0 on the USDT exchange");
        require(usdcExchange.asset0 == cUSD, "cUSD is not asset0 on the USDC exchange");

        usdtExchange.asset1 = USDT;
        usdcExchange.asset1 = USDC;

        console.log(unicode"💀 Destroying USDT and USDC exchanges");
        if (usdcExchangeId > usdtExchangeId) {
            biPoolManagerWrite.destroyExchange(usdcExchangeId, usdcExchangeIdIndex);
            biPoolManagerWrite.destroyExchange(usdtExchangeId, usdtExchangeIdIndex);
        } else {
            biPoolManagerWrite.destroyExchange(usdtExchangeId, usdtExchangeIdIndex);
            biPoolManagerWrite.destroyExchange(usdcExchangeId, usdcExchangeIdIndex);
        }

        console.log(unicode"🔄 Re-creating USDT and USDC exchanges");
        bytes32 newUsdtExchangeId = biPoolManagerWrite.createExchange(usdtExchange);
        bytes32 newUsdcExchangeId = biPoolManagerWrite.createExchange(usdcExchange);

        console.log(unicode"🔄 Configuring trading limits for new exchanges");
        brokerWrite.configureTradingLimit(newUsdtExchangeId, cUSD, usdtLimit);
        brokerWrite.configureTradingLimit(newUsdcExchangeId, cUSD, usdcLimit);

        bytes32 newUsdtLimitId = newUsdtExchangeId ^ bytes32(uint256(uint160(cUSD)));
        bytes32 newUsdcLimitId = newUsdcExchangeId ^ bytes32(uint256(uint160(cUSD)));

        ITradingLimits.Config memory newUsdtLimit = broker.tradingLimitsConfig(newUsdtLimitId);
        ITradingLimits.Config memory newUsdcLimit = broker.tradingLimitsConfig(newUsdcLimitId);

        require(
            keccak256(abi.encode(newUsdtLimit)) == keccak256(abi.encode(usdtLimit)),
            "New USDT Limits don't match the old one"
        );
        require(
            keccak256(abi.encode(newUsdcLimit)) == keccak256(abi.encode(usdcLimit)),
            "New USDC Limits don't match the old one"
        );

        postChecks();
    }

    function getExchange(address asset0, address asset1)
        public
        view
        returns (IBiPoolManager.PoolExchange memory, uint256, bytes32)
    {
        IExchangeProvider.Exchange[] memory exchanges = biPoolManager.getExchanges();
        for (uint256 i = exchanges.length - 1; i >= 0; i--) {
            IExchangeProvider.Exchange memory exchange = exchanges[i];
            if (
                (exchange.assets[0] == asset0 && exchange.assets[1] == asset1)
                    || (exchange.assets[0] == asset1 && exchange.assets[1] == asset0)
            ) {
                return (biPoolManager.exchanges(exchange.exchangeId), i, exchange.exchangeId);
            }
            if (i == 0) break;
        }

        revert ExchangeNotFound();
    }
}
