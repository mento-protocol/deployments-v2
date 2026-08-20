// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";
import {IMedianDeltaBreaker} from "mento-core/interfaces/IMedianDeltaBreaker.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

/// @title ResetTestnetBreakers
/// @notice Resets the tripped MedianDeltaBreaker state for the COP/USD and GHS/USD
///         feeds on Celo Sepolia. The breaker is disabled before its EMA is reset,
///         then re-enabled so it seeds a new baseline from the current median. The
///         action is idempotent. Set recoverDisabled only to resume an interrupted
///         broadcast that left a MedianDeltaBreaker disabled.
contract ResetTestnetBreakers is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    uint256 internal constant CELO_SEPOLIA_CHAIN_ID = 11142220;
    uint8 internal constant TRADING_MODE_BIDIRECTIONAL = 0;
    uint8 internal constant TRADING_MODE_INFLOW_ONLY = 1;

    address internal constant COP_USD_RATE_FEED = 0x7149632514c5BAA315520Ab9d12556D9C67F15E0;
    address internal constant GHS_USD_RATE_FEED = 0xbB776CD80Bab1E658A6a8685580751166145121F;

    address internal breakerBox;
    address internal medianDeltaBreaker;

    function setUp() public {
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        medianDeltaBreaker = lookupOrFail("MedianDeltaBreaker:v2.6.5");
    }

    /// @custom:env {bool:optional} recoverDisabled - Resume a reset that left the breaker disabled (default false)
    /// @custom:senders deployer
    function run() public broadcast {
        require(block.chainid == CELO_SEPOLIA_CHAIN_ID, "ResetTestnetBreakers: only runnable on Celo Sepolia");

        Senders.Sender storage deployer = sender("deployer");
        require(IOwnable(breakerBox).owner() == deployer.account, "deployer does not own BreakerBox");
        require(
            IMedianDeltaBreaker(medianDeltaBreaker).owner() == deployer.account,
            "deployer does not own MedianDeltaBreaker"
        );

        IBreakerBox breakerBoxRead = IBreakerBox(breakerBox);
        IBreakerBox breakerBoxWrite = IBreakerBox(deployer.harness(breakerBox));
        IMedianDeltaBreaker medianBreakerRead = IMedianDeltaBreaker(medianDeltaBreaker);
        IMedianDeltaBreaker medianBreakerWrite = IMedianDeltaBreaker(deployer.harness(medianDeltaBreaker));
        bool recoverDisabled = vm.envOr("recoverDisabled", false);

        _resetFeed(
            breakerBoxRead,
            breakerBoxWrite,
            medianBreakerRead,
            medianBreakerWrite,
            COP_USD_RATE_FEED,
            "COP/USD",
            recoverDisabled
        );
        _resetFeed(
            breakerBoxRead,
            breakerBoxWrite,
            medianBreakerRead,
            medianBreakerWrite,
            GHS_USD_RATE_FEED,
            "GHS/USD",
            recoverDisabled
        );
    }

    function _resetFeed(
        IBreakerBox breakerBoxRead,
        IBreakerBox breakerBoxWrite,
        IMedianDeltaBreaker medianBreakerRead,
        IMedianDeltaBreaker medianBreakerWrite,
        address rateFeed,
        string memory label,
        bool recoverDisabled
    ) internal {
        IBreakerBox.BreakerStatus memory status = breakerBoxRead.rateFeedBreakerStatus(rateFeed, medianDeltaBreaker);

        if (status.enabled && status.tradingMode == TRADING_MODE_BIDIRECTIONAL) {
            _requireReset(breakerBoxRead, medianBreakerRead, rateFeed, label);
            console.log(string.concat(label, " MedianDeltaBreaker is already reset"));
            return;
        }

        if (status.enabled) {
            require(
                status.tradingMode == TRADING_MODE_INFLOW_ONLY,
                string.concat(label, " MedianDeltaBreaker has an unexpected trading mode")
            );
            breakerBoxWrite.toggleBreaker(medianDeltaBreaker, rateFeed, false);
        } else {
            require(
                status.tradingMode == TRADING_MODE_BIDIRECTIONAL,
                string.concat(label, " disabled MedianDeltaBreaker has an unexpected trading mode")
            );
            require(
                recoverDisabled,
                string.concat(label, " MedianDeltaBreaker is disabled; set recoverDisabled=true to resume")
            );
            console.log(string.concat(label, " MedianDeltaBreaker is disabled; resuming reset"));
        }

        if (medianBreakerRead.medianRatesEMA(rateFeed) != 0) {
            medianBreakerWrite.resetMedianRateEMA(rateFeed);
        }

        status = breakerBoxRead.rateFeedBreakerStatus(rateFeed, medianDeltaBreaker);
        require(!status.enabled, string.concat(label, " MedianDeltaBreaker was not disabled"));
        breakerBoxWrite.toggleBreaker(medianDeltaBreaker, rateFeed, true);

        _requireReset(breakerBoxRead, medianBreakerRead, rateFeed, label);
        console.log(string.concat(label, " MedianDeltaBreaker reset"));
        console.log("Aggregate trading mode:", breakerBoxRead.getRateFeedTradingMode(rateFeed));
    }

    function _requireReset(
        IBreakerBox breakerBoxRead,
        IMedianDeltaBreaker medianBreakerRead,
        address rateFeed,
        string memory label
    ) internal view {
        IBreakerBox.BreakerStatus memory status = breakerBoxRead.rateFeedBreakerStatus(rateFeed, medianDeltaBreaker);

        require(status.enabled, string.concat(label, " MedianDeltaBreaker was not re-enabled"));
        require(
            status.tradingMode == TRADING_MODE_BIDIRECTIONAL, string.concat(label, " MedianDeltaBreaker did not reset")
        );
        require(medianBreakerRead.medianRatesEMA(rateFeed) > 0, string.concat(label, " EMA was not reseeded"));
        require(
            breakerBoxRead.getRateFeedTradingMode(rateFeed) == TRADING_MODE_BIDIRECTIONAL,
            string.concat(label, " aggregate trading mode is not bidirectional")
        );
    }
}
