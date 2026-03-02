// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IMarketHoursBreaker} from "mento-core/interfaces/IMarketHoursBreaker.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";

/**
 * @title OracleBreaker
 * @notice Tests MarketHoursBreaker enabled on FX feeds
 */
contract OracleBreaker is V3IntegrationBase {

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
