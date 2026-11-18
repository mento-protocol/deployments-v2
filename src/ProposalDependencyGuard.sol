// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal view of an OpenZeppelin Governor.
interface IGovernorState {
    /// @return state Pending(0) Active(1) Canceled(2) Defeated(3) Succeeded(4) Queued(5) Expired(6) Executed(7)
    function state(uint256 proposalId) external view returns (uint8 state);
}

/**
 * @title ProposalDependencyGuard
 * @notice Stateless helper that lets a governance proposal declare "execute me only after proposal X has settled".
 * @dev OpenZeppelin's GovernorTimelockControl always schedules timelock operations with predecessor = 0, so there is
 *      no native way to order two proposals of the same Governor. Including
 *      `requireSettled(governor, dependencyId)` as a call in the dependent proposal achieves the same effect: while
 *      the dependency is still Pending, Active, Succeeded or Queued the call reverts and, with it, the whole timelock
 *      batch. The dependent proposal simply stays Queued and can be executed once the dependency has been Executed
 *      (or has been Canceled / Defeated / Expired, in which case there is nothing left to wait for).
 *
 *      The guard holds no state and no permissions; anyone can call it.
 */
contract ProposalDependencyGuard {
    uint8 internal constant CANCELED = 2;
    uint8 internal constant DEFEATED = 3;
    uint8 internal constant EXPIRED = 6;
    uint8 internal constant EXECUTED = 7;

    error DependencyNotSettled(address governor, uint256 proposalId, uint8 state);

    /// @notice Reverts unless `proposalId` on `governor` is Executed, Canceled, Defeated or Expired.
    function requireSettled(address governor, uint256 proposalId) external view {
        uint8 s = IGovernorState(governor).state(proposalId);
        if (s == EXECUTED || s == CANCELED || s == DEFEATED || s == EXPIRED) return;
        revert DependencyNotSettled(governor, proposalId, s);
    }

    /// @notice View helper: true if `requireSettled` would pass.
    function isSettled(address governor, uint256 proposalId) external view returns (bool) {
        uint8 s = IGovernorState(governor).state(proposalId);
        return s == EXECUTED || s == CANCELED || s == DEFEATED || s == EXPIRED;
    }
}
