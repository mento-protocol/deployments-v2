// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IReserveLiquidityStrategy} from "mento-core/interfaces/IReserveLiquidityStrategy.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

contract ConfigureV3PreStage is
    TrebScript,
    ProxyHelper,
    PostChecksHelper
{
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    address breakerBox;
    address marketHoursBreaker;
    address reserveV2;
    address reserveLiquidityStrategy;
    address reserveSafe;
    address[] fxFeedIds;

    function setUp() public {
        config = Config.get();
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        reserveV2 = lookupProxyOrFail("ReserveV2");
        reserveLiquidityStrategy = lookupProxyOrFail("ReserveLiquidityStrategy");
        fxFeedIds = config.getFxRateFeedIds();
        reserveSafe = lookupOrFail("ReserveSafe");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        // --- BreakerBox: add & enable MarketHoursBreaker on FX feeds ---
        IBreakerBox bbWrite = IBreakerBox(owner.harness(breakerBox));
        IBreakerBox bbRead = IBreakerBox(breakerBox);

        if (!bbRead.isBreaker(marketHoursBreaker)) {
            bbWrite.addBreaker(marketHoursBreaker, 3);
        }

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            if (!bbRead.isBreakerEnabled(marketHoursBreaker, fxFeedIds[i])) {
                bbWrite.toggleBreaker(marketHoursBreaker, fxFeedIds[i], true);
            }
        }

        // --- ReserveV2: register addresses ---
        IReserveV2 rvWrite = IReserveV2(owner.harness(reserveV2));
        IReserveV2 rvRead = IReserveV2(reserveV2);

        if (!rvRead.isOtherReserveAddress(reserveSafe)) {
            rvWrite.registerOtherReserveAddress(reserveSafe);
        }
        if (!rvRead.isReserveManagerSpender(reserveSafe)) {
            rvWrite.registerReserveManagerSpender(reserveSafe);
        }
        if (!rvRead.isLiquidityStrategySpender(reserveLiquidityStrategy)) {
            rvWrite.registerLiquidityStrategySpender(reserveLiquidityStrategy);
        }

        postChecks();
    }

    function postChecks() internal view {
        address ownerAccount = sender("migrationOwner").account;
        IBreakerBox bbRead = IBreakerBox(breakerBox);
        IReserveV2 rvRead = IReserveV2(reserveV2);

        // Config sanity
        require(fxFeedIds.length > 0, "No FX rate feed IDs configured");

        // BreakerBox: breaker registered with correct trading mode
        require(
            bbRead.isBreaker(marketHoursBreaker),
            "MarketHoursBreaker not added to BreakerBox"
        );
        require(
            bbRead.breakerTradingMode(marketHoursBreaker) == 3,
            "MarketHoursBreaker trading mode is not 3 (halted)"
        );

        // BreakerBox: breaker enabled on all FX feeds
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            require(
                bbRead.isBreakerEnabled(marketHoursBreaker, fxFeedIds[i]),
                "MarketHoursBreaker not enabled for FX feed"
            );
        }

        // ReserveV2: registrations
        require(
            rvRead.isOtherReserveAddress(reserveSafe),
            "ReserveSafe not registered as other reserve address"
        );
        require(
            rvRead.isReserveManagerSpender(reserveSafe),
            "ReserveSafe not registered as reserve manager spender"
        );
        require(
            rvRead.isLiquidityStrategySpender(reserveLiquidityStrategy),
            "ReserveLiquidityStrategy not registered as liquidity strategy spender"
        );
    }
}
