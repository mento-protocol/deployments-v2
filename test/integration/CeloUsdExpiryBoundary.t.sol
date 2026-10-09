// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

/// @dev SortedOracles admin function not exposed by mento-core's ISortedOracles.
interface ISortedOraclesExpiry {
    function setTokenReportExpiry(address token, uint256 expirySeconds) external;
}

/// @dev Chainlink AggregatorV3Interface subset the relayer reads.
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IChainlinkRelayerErrors {
    error ExpiredTimestamp();
}

/**
 * @title CeloUsdExpiryBoundary
 * @notice Functional evidence for MGP-20 Part 2: with the CELO/USD report expiry at 1 day + 5
 *         minutes, the CELO/USD ChainlinkRelayerV1 accepts a Chainlink observation that is
 *         86,699 s old and rejects one that is 86,700 s old (`ExpiredTimestamp`), and the
 *         SortedOracles median keeps being served while the single report reads as expired.
 * @dev Celo mainnet only (the legacy CELO/USD rate feed id is the USDm proxy). The expiry is
 *      set by pranking the SortedOracles owner (the migration multisig) unless it already is
 *      at the target, so the tests hold both before and after Part 2a executes on-chain.
 */
contract CeloUsdExpiryBoundary is V3IntegrationBase {
    uint256 internal constant NEW_EXPIRY = 1 days + 5 minutes;

    address internal relayer;
    address internal celoUsdRateFeedId;
    address internal aggregator;

    function setUp() public override {
        super.setUp();
        if (block.chainid != 42220) {
            vm.skip(true);
            return;
        }

        relayer = lookupOrFail("ChainlinkRelayerV1:CELOUSD");
        celoUsdRateFeedId = lookupProxyOrFail("USDm");
        assertEq(IChainlinkRelayer(relayer).rateFeedId(), celoUsdRateFeedId, "relayer does not report CELO/USD");
        assertEq(IChainlinkRelayer(relayer).sortedOracles(), sortedOracles, "relayer reports elsewhere");

        IChainlinkRelayer.ChainlinkAggregator[] memory aggregators = IChainlinkRelayer(relayer).getAggregators();
        assertEq(aggregators.length, 1, "CELO/USD relayer should read a single aggregator");
        aggregator = aggregators[0].aggregator;
        assertTrue(ISortedOracles(sortedOracles).isOracle(celoUsdRateFeedId, relayer), "relayer not an oracle");
    }

    // ========== Tests ==========

    /// @notice (a) An observation one second inside the new expiry is relayed and the report advances.
    function test_celoUsd_relayAcceptsObservationOneSecondInsideExpiry() public {
        _ensureNewExpiry();
        uint256 lastReport = ISortedOracles(sortedOracles).medianTimestamp(celoUsdRateFeedId);

        // Strictly newer than the existing report: the TimestampNotNew check runs before the expiry check.
        uint256 observedAt = lastReport + 1;
        int256 answer = _mockObservation(observedAt);
        vm.warp(observedAt + NEW_EXPIRY - 1); // observation age 86,699 s

        IChainlinkRelayer(relayer).relay();

        assertEq(
            ISortedOracles(sortedOracles).medianTimestamp(celoUsdRateFeedId), block.timestamp, "report did not advance"
        );
        assertGt(block.timestamp, lastReport, "clock did not move");
        // The relayer scales the Chainlink answer to SortedOracles' 24-decimal Fixidity format.
        (uint256 rateAfter,) = ISortedOracles(sortedOracles).medianRate(celoUsdRateFeedId);
        uint256 expectedMedian = uint256(answer) * 10 ** (24 - uint256(IAggregatorV3(aggregator).decimals()));
        assertEq(rateAfter, expectedMedian, "median should equal the relayed Chainlink answer");
    }

    /// @notice (b) An observation exactly as old as the expiry is rejected with ExpiredTimestamp.
    function test_celoUsd_relayRejectsObservationAtExpiry() public {
        _ensureNewExpiry();
        uint256 lastReport = ISortedOracles(sortedOracles).medianTimestamp(celoUsdRateFeedId);

        uint256 observedAt = lastReport + 1;
        _mockObservation(observedAt);
        vm.warp(observedAt + NEW_EXPIRY); // observation age 86,700 s

        vm.expectRevert(IChainlinkRelayerErrors.ExpiredTimestamp.selector);
        IChainlinkRelayer(relayer).relay();

        assertEq(ISortedOracles(sortedOracles).medianTimestamp(celoUsdRateFeedId), lastReport, "report must not change");
    }

    /// @notice (c) A missed daily relay leaves the report expired but the median keeps being served:
    ///         removeExpiredReports refuses to remove the last report and medianRate ignores expiry.
    function test_celoUsd_expiredSingleReportKeepsServingMedian() public {
        _ensureNewExpiry();
        uint256 lastReport = ISortedOracles(sortedOracles).medianTimestamp(celoUsdRateFeedId);
        (uint256 rateBefore,) = ISortedOracles(sortedOracles).medianRate(celoUsdRateFeedId);
        assertEq(ISortedOracles(sortedOracles).numRates(celoUsdRateFeedId), 1, "expected the single relayer report");

        vm.warp(lastReport + 2 days); // two missed daily relays

        (bool expired,) = ISortedOracles(sortedOracles).isOldestReportExpired(celoUsdRateFeedId);
        assertTrue(expired, "report should read as expired after two days without a relay");

        // SortedOracles requires n < numTimestamps, so the last report can never be removed.
        vm.expectRevert(bytes("token addr null or trying to remove too many reports"));
        ISortedOracles(sortedOracles).removeExpiredReports(celoUsdRateFeedId, 1);
        assertEq(ISortedOracles(sortedOracles).numRates(celoUsdRateFeedId), 1, "last report must not be removable");
        (uint256 rateAfter,) = ISortedOracles(sortedOracles).medianRate(celoUsdRateFeedId);
        assertEq(rateAfter, rateBefore, "median must keep being served");
        assertGt(rateAfter, 0, "median must stay nonzero");
    }

    // ========== Helpers ==========

    /// @dev Sets the CELO/USD expiry to 1 day + 5 minutes as the SortedOracles owner, unless it
    ///      is already there (setTokenReportExpiry reverts on an unchanged value).
    function _ensureNewExpiry() internal {
        uint256 current = ISortedOracles(sortedOracles).getTokenReportExpirySeconds(celoUsdRateFeedId);
        if (current != NEW_EXPIRY) {
            vm.prank(IOwnable(sortedOracles).owner());
            ISortedOraclesExpiry(sortedOracles).setTokenReportExpiry(celoUsdRateFeedId, NEW_EXPIRY);
        }
        assertEq(ISortedOracles(sortedOracles).getTokenReportExpirySeconds(celoUsdRateFeedId), NEW_EXPIRY);
    }

    /// @dev Replays the aggregator's current answer with a chosen observation timestamp, so the
    ///      relayed value is unchanged (no breaker interaction) and only the age differs.
    function _mockObservation(uint256 observedAt) internal returns (int256 answer) {
        (uint80 roundId, int256 liveAnswer,,, uint80 answeredInRound) = IAggregatorV3(aggregator).latestRoundData();
        answer = liveAnswer;
        assertGt(answer, 0, "live Chainlink answer must be positive");
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(IAggregatorV3.latestRoundData.selector),
            abi.encode(roundId, answer, observedAt, observedAt, answeredInRound)
        );
    }
}
