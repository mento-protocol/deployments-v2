// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// solhint-disable-next-line max-line-length
import {
    BokkyPooBahsDateTimeLibrary as DateTimeLibrary
} from "lib/mento-core/lib/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

/**
 * @title MarketHoursBreakerToggleable
 * @notice A variant of MarketHoursBreaker with a toggle for market hours checks.
 *         When checks are disabled (default), isFXMarketOpen always returns true
 *         (market considered open). The owner can enable checks to use the real
 *         market hours logic.
 * @dev    Does not declare IMarketHoursBreaker conformance because the interface
 *         marks isFXMarketOpen as pure, but this contract needs view to read the
 *         checksEnabled flag. ABI-compatible so it works when cast to the interface.
 */
contract MarketHoursBreakerToggleable is Ownable {
    bool public checksEnabled;

    event ChecksToggled(bool enabled);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setChecksEnabled(bool _enabled) external onlyOwner {
        checksEnabled = _enabled;
        emit ChecksToggled(_enabled);
    }

    function isFXMarketOpen(uint256 timestamp) public view returns (bool) {
        if (!checksEnabled) {
            return true;
        }
        return !_isWeekendHours(timestamp) && !_isHoliday(timestamp);
    }

    // solhint-disable-next-line no-unused-vars
    function shouldTrigger(
        address /* rateFeedID */
    )
        public
        view
        returns (bool triggerBreaker)
    {
        require(isFXMarketOpen(block.timestamp), "MarketHoursBreaker: FX market is closed");

        return false;
    }

    /* ============================================================ */
    /* ===================== Internal Functions =================== */
    /* ============================================================ */

    function _isWeekendHours(uint256 timestamp) internal pure returns (bool) {
        uint256 dow = DateTimeLibrary.getDayOfWeek(timestamp);
        uint256 hour = DateTimeLibrary.getHour(timestamp);

        // slither-disable-start incorrect-equality
        bool isFridayEvening = dow == 5 && hour >= 21;
        bool isSaturday = dow == 6;
        bool isSundayBeforeEvening = dow == 7 && hour < 23;
        // slither-disable-end incorrect-equality

        return isFridayEvening || isSaturday || isSundayBeforeEvening;
    }

    function _isHoliday(uint256 timestamp) internal pure returns (bool) {
        uint256 month = DateTimeLibrary.getMonth(timestamp);
        uint256 day = DateTimeLibrary.getDay(timestamp);

        // slither-disable-start incorrect-equality
        if (month == 12) {
            if (day == 24 || day == 31) {
                return DateTimeLibrary.getHour(timestamp) >= 22;
            }

            return day == 25;
        }

        return (month == 1 && day == 1);
        // slither-disable-end incorrect-equality
    }
}
