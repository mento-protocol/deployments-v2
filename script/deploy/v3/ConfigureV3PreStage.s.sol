// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";

contract ConfigureV3PreStage is
    TrebScript,
    AddressbookHelper,
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
    address reserveV1;
    address[] fxFeedIds;

    function setUp() public {
        config = Config.get();
        breakerBox = config.getDeployedContract("BreakerBox");
        marketHoursBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        reserveV2 = lookupProxyOrFail("ReserveV2");
        reserveLiquidityStrategy = lookupProxyOrFail("ReserveLiquidityStrategy");
        reserveV1 = lookup("Reserve");
        fxFeedIds = config.getFxRateFeedIds();
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        // --- BreakerBox: add & enable MarketHoursBreaker on FX feeds ---
        IBreakerBox bbWrite = IBreakerBox(deployer.harness(breakerBox));
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
        IReserveV2 rvWrite = IReserveV2(deployer.harness(reserveV2));
        IReserveV2 rvRead = IReserveV2(reserveV2);

        if (!rvRead.isOtherReserveAddress(reserveV1)) {
            rvWrite.registerOtherReserveAddress(reserveV1);
        }
        if (!rvRead.isReserveManagerSpender(reserveV1)) {
            rvWrite.registerReserveManagerSpender(reserveV1);
        }
        if (!rvRead.isLiquidityStrategySpender(reserveLiquidityStrategy)) {
            rvWrite.registerLiquidityStrategySpender(reserveLiquidityStrategy);
        }

        postChecks();
    }

    function postChecks() internal view {
        IBreakerBox bbRead = IBreakerBox(breakerBox);
        IReserveV2 rvRead = IReserveV2(reserveV2);

        require(
            bbRead.isBreaker(marketHoursBreaker),
            "MarketHoursBreaker not added to BreakerBox"
        );
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            require(
                bbRead.isBreakerEnabled(marketHoursBreaker, fxFeedIds[i]),
                "MarketHoursBreaker not enabled for FX feed"
            );
        }
        require(
            rvRead.isOtherReserveAddress(reserveV1),
            "ReserveV1 not registered as other reserve address"
        );
        require(
            rvRead.isReserveManagerSpender(reserveV1),
            "ReserveV1 not registered as reserve manager spender"
        );
        require(
            rvRead.isLiquidityStrategySpender(reserveLiquidityStrategy),
            "ReserveLiquidityStrategy not registered as liquidity strategy spender"
        );
    }
}
