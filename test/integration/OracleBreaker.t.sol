// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IMarketHoursBreaker} from "mento-core/interfaces/IMarketHoursBreaker.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";

/**
 * @title OracleBreaker
 * @notice Tests MarketHoursBreaker behavior and OracleAdapter rate validity
 *         during FX market open/closed hours.
 */
contract OracleBreaker is V3IntegrationBase {
    // Wednesday 2024-08-14 12:00:00 UTC — FX market open
    uint256 constant MARKET_OPEN_TIMESTAMP = 1723636800;
    // Saturday 2024-08-10 12:00:00 UTC — FX market closed
    uint256 constant MARKET_CLOSED_TIMESTAMP = 1723291200;

    // ========== Market Hours: OracleAdapter.getFXRateIfValid ==========

    function test_getFXRateIfValid_duringMarketHours_returnsNonZero() public {
        vm.warp(MARKET_OPEN_TIMESTAMP);

        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            (uint256 numerator, uint256 denominator) = IOracleAdapter(oracleAdapter).getFXRateIfValid(fxFeedIds[i]);
            assertGt(numerator, 0, string.concat("Zero numerator for FX feed: ", vm.toString(fxFeedIds[i])));
            assertGt(denominator, 0, string.concat("Zero denominator for FX feed: ", vm.toString(fxFeedIds[i])));
        }
    }

    function test_isFXMarketOpen_duringMarketHours_returnsTrue() public {
        vm.warp(MARKET_OPEN_TIMESTAMP);
        assertTrue(IOracleAdapter(oracleAdapter).isFXMarketOpen(), "FX market should be open on Wednesday noon");
    }

    // ========== Outside Market Hours: Breaker Triggers ==========

    function test_isFXMarketOpen_outsideMarketHours_returnsFalse() public {
        vm.warp(MARKET_CLOSED_TIMESTAMP);
        assertFalse(IOracleAdapter(oracleAdapter).isFXMarketOpen(), "FX market should be closed on Saturday");
    }

    function test_getFXRateIfValid_outsideMarketHours_reverts() public {
        vm.warp(MARKET_CLOSED_TIMESTAMP);

        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            vm.expectRevert(IOracleAdapter.FXMarketClosed.selector);
            IOracleAdapter(oracleAdapter).getFXRateIfValid(fxFeedIds[i]);
        }
    }

    // ========== MarketHoursBreaker Direct Tests ==========

    function test_marketHoursBreaker_isFXMarketOpen_openTimestamp() public view {
        assertTrue(
            IMarketHoursBreaker(marketHoursBreaker).isFXMarketOpen(MARKET_OPEN_TIMESTAMP),
            "MarketHoursBreaker: should report open on Wednesday noon"
        );
    }

    function test_marketHoursBreaker_isFXMarketOpen_closedTimestamp() public view {
        assertFalse(
            IMarketHoursBreaker(marketHoursBreaker).isFXMarketOpen(MARKET_CLOSED_TIMESTAMP),
            "MarketHoursBreaker: should report closed on Saturday"
        );
    }

    function test_marketHoursBreaker_shouldTrigger_duringMarketHours() public {
        vm.warp(MARKET_OPEN_TIMESTAMP);

        address[] memory fxFeedIds = config.getFxRateFeedIds();
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            bool triggered = IMarketHoursBreaker(marketHoursBreaker).shouldTrigger(fxFeedIds[i]);
            assertFalse(triggered, "shouldTrigger should return false during market hours");
        }
    }

    function test_marketHoursBreaker_shouldTrigger_outsideMarketHours_reverts() public {
        vm.warp(MARKET_CLOSED_TIMESTAMP);

        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            vm.expectRevert("MarketHoursBreaker: FX market is closed");
            IMarketHoursBreaker(marketHoursBreaker).shouldTrigger(fxFeedIds[i]);
        }
    }

    // ========== BreakerBox Trading Mode Tests ==========

    function test_breakerBox_tradingMode_duringMarketHours() public {
        vm.warp(MARKET_OPEN_TIMESTAMP);

        address[] memory fxFeedIds = config.getFxRateFeedIds();
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            uint8 tradingMode = IBreakerBox(breakerBox).getRateFeedTradingMode(fxFeedIds[i]);
            assertEq(
                tradingMode,
                0,
                string.concat("Expected bidirectional trading (mode 0) for feed: ", vm.toString(fxFeedIds[i]))
            );
        }
    }

    function test_breakerBox_marketHoursBreaker_enabledOnFxFeeds() public view {
        address[] memory fxFeedIds = config.getFxRateFeedIds();
        assertGt(fxFeedIds.length, 0, "No FX rate feed IDs configured");

        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            assertTrue(
                IBreakerBox(breakerBox).isBreakerEnabled(marketHoursBreaker, fxFeedIds[i]),
                string.concat("MarketHoursBreaker not enabled on FX feed: ", vm.toString(fxFeedIds[i]))
            );
        }
    }
}
