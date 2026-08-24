// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {ProposalDependencyGuard} from "src/ProposalDependencyGuard.sol";

/// @dev Minimal lifecycle interface of the deployed MentoGovernor
///      (OZ GovernorUpgradeable + GovernorCompatibilityBravo + GovernorTimelockControl).
interface IGovernorLifecycle {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256);

    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        external
        returns (uint256);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    function state(uint256 proposalId) external view returns (uint8);

    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function quorum(uint256 blockNumber) external view returns (uint256);

    function getVotes(address account, uint256 blockNumber) external view returns (uint256);
}

/// @dev Minimal interface of the deployed Locking (veMENTO) contract.
interface ILockingFork {
    function token() external view returns (address);

    function lock(address account, address _delegate, uint96 amount, uint32 slopePeriod, uint32 cliff)
        external
        returns (uint256);
}

interface ITimelockDelayView {
    function getMinDelay() external view returns (uint256);
}

interface IERC20Approve {
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @dev Records that a proposal transaction actually executed, and by whom.
contract ExecutionProbe {
    address public lastCaller;
    bool public marked;

    function mark() external {
        marked = true;
        lastCaller = msg.sender;
    }
}

/**
 * @title ProposalDependencyGuardForkTest
 * @notice Fork tests for ProposalDependencyGuard against the actually deployed
 *         MentoGovernor + TimelockController on Celo mainnet.
 *
 *         Simulates the MGP-19 proposal structure end to end: a dependent proposal
 *         carries `guard.requireSettled(governor, dependencyId)` as transaction 0
 *         (mirroring the MGP-19 bundle), and both proposals are driven through the
 *         real Bravo lifecycle: propose -> vote -> queue -> execute. Voting power is
 *         real veMENTO obtained by locking MENTO on the fork.
 *
 *         Verifies that the dependent proposal:
 *         - cannot execute before its timelock delay (baseline timelock behavior),
 *         - cannot execute while the dependency is still Queued (the guard call
 *           reverts and takes the whole timelock batch with it),
 *         - stays Queued through such a failed attempt,
 *         - executes fine once the dependency has been Executed (or Defeated).
 *
 *         Environment: FORK_URL must point at a Celo mainnet RPC (chain 42220).
 */
contract ProposalDependencyGuardForkTest is V3IntegrationBase {
    uint8 internal constant ACTIVE = 1;
    uint8 internal constant DEFEATED = 3;
    uint8 internal constant SUCCEEDED = 4;
    uint8 internal constant QUEUED = 5;
    uint8 internal constant EXECUTED = 7;

    uint8 internal constant VOTE_AGAINST = 0;
    uint8 internal constant VOTE_FOR = 1;

    /// @dev Locking's max slope/cliff periods -> max veMENTO weight for the locked amount.
    uint32 internal constant MAX_SLOPE_PERIOD = 104;
    uint32 internal constant MAX_CLIFF_PERIOD = 103;

    /// @dev 200M MENTO (20% of total supply) locked at max weight dwarfs current
    ///      veMENTO supply, so the voter single-handedly clears quorum. Asserted in _propose.
    uint96 internal constant LOCK_AMOUNT = 200_000_000e18;

    address internal governor;
    address internal timelock;
    address internal locking;
    address internal voter = makeAddr("veMentoWhale");

    ProposalDependencyGuard internal guard;
    ExecutionProbe internal probeA;
    ExecutionProbe internal probeB;

    function setUp() public override {
        // Lean replication of the base setUp: fork + registry only, no config / oracle refresh.
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }

        string memory namespace = vm.envOr("NAMESPACE", string("default"));
        registry = new Registry(namespace, ".treb/registry.json", ".treb/addressbook.json");

        governor = lookupProxyOrFail("MentoGovernor");
        timelock = lookupProxyOrFail("TimelockController");
        locking = lookupProxyOrFail("Locking");

        guard = new ProposalDependencyGuard();
        probeA = new ExecutionProbe();
        probeB = new ExecutionProbe();

        // Real voting power: deal MENTO, lock it for max veMENTO weight.
        address mento = ILockingFork(locking).token();
        deal(mento, voter, LOCK_AMOUNT);
        vm.startPrank(voter);
        IERC20Approve(mento).approve(locking, LOCK_AMOUNT);
        ILockingFork(locking).lock(voter, voter, LOCK_AMOUNT, MAX_SLOPE_PERIOD, MAX_CLIFF_PERIOD);
        vm.stopPrank();

        // The proposal threshold check reads votes at block.number - 1, so the lock
        // must be at least two blocks behind the propose call.
        _advance(2);
    }

    // ========== The MGP-19 ordering: dependent proposal waits for the dependency ==========

    /// @notice Full lifecycle on the deployed contracts: the dependent proposal (guard as tx 0,
    ///         like MGP-19) is queued but cannot execute until the dependency proposal
    ///         (stand-in for MGP-18) has gone through timelock execution.
    function test_dependentProposal_executesOnlyAfterDependencyExecuted() public {
        // Dependency proposal "A" and dependent proposal "B" (tx 0 = guard, tx 1 = payload).
        (uint256 idA, address[] memory tA, bytes[] memory cA, bytes32 hA) = _proposeDependency();
        assertFalse(guard.isSettled(governor, idA), "Pending dependency must not count as settled");

        (uint256 idB, address[] memory tB, bytes[] memory cB, bytes32 hB) = _proposeDependent(idA);

        // A and B share one voting window: both were proposed in the same block.
        uint256[] memory ids = new uint256[](2);
        ids[0] = idA;
        ids[1] = idB;
        _voteAll(ids, VOTE_FOR);

        IGovernorLifecycle(governor).queue(tA, _zeroes(tA.length), cA, hA);
        IGovernorLifecycle(governor).queue(tB, _zeroes(tB.length), cB, hB);
        assertEq(IGovernorLifecycle(governor).state(idA), QUEUED);
        assertEq(IGovernorLifecycle(governor).state(idB), QUEUED);

        // Baseline: before the timelock delay neither the delay nor the guard lets B through.
        vm.expectRevert("TimelockController: operation is not ready");
        IGovernorLifecycle(governor).execute(tB, _zeroes(tB.length), cB, hB);

        _advance(ITimelockDelayView(timelock).getMinDelay() + 1);

        // The guard itself reverts with the dependency's live state (Queued)...
        assertFalse(guard.isSettled(governor, idA), "Queued dependency must not count as settled");
        vm.expectRevert(
            abi.encodeWithSelector(ProposalDependencyGuard.DependencyNotSettled.selector, governor, idA, QUEUED)
        );
        guard.requireSettled(governor, idA);

        // ...and through the timelock batch that revert blocks the whole dependent proposal.
        vm.expectRevert("TimelockController: underlying transaction reverted");
        IGovernorLifecycle(governor).execute(tB, _zeroes(tB.length), cB, hB);

        // The failed attempt is not consuming: B simply stays Queued, nothing executed.
        assertEq(IGovernorLifecycle(governor).state(idB), QUEUED, "B must stay Queued after the failed attempt");
        assertFalse(probeB.marked(), "B's payload must not have executed");

        // Execute the dependency through its timelock.
        IGovernorLifecycle(governor).execute(tA, _zeroes(tA.length), cA, hA);
        assertEq(IGovernorLifecycle(governor).state(idA), EXECUTED);
        assertTrue(probeA.marked(), "A's payload must have executed");
        assertTrue(guard.isSettled(governor, idA), "Executed dependency must count as settled");

        // Now the exact same call succeeds.
        IGovernorLifecycle(governor).execute(tB, _zeroes(tB.length), cB, hB);
        assertEq(IGovernorLifecycle(governor).state(idB), EXECUTED);
        assertTrue(probeB.marked(), "B's payload must have executed");
        assertEq(probeB.lastCaller(), timelock, "B's payload must execute from the timelock");
    }

    /// @notice A Defeated dependency counts as settled: there is nothing left to wait for,
    ///         so the dependent proposal executes normally.
    function test_dependentProposal_executesWhenDependencyDefeated() public {
        (uint256 idA,,,) = _proposeDependency();
        _voteAndSucceed(idA, VOTE_AGAINST); // drives A to Defeated
        assertEq(IGovernorLifecycle(governor).state(idA), DEFEATED);
        assertTrue(guard.isSettled(governor, idA), "Defeated dependency must count as settled");

        (uint256 idB, address[] memory tB, bytes[] memory cB, bytes32 hB) = _proposeDependent(idA);
        _voteAndSucceed(idB, VOTE_FOR);
        IGovernorLifecycle(governor).queue(tB, _zeroes(tB.length), cB, hB);
        _advance(ITimelockDelayView(timelock).getMinDelay() + 1);

        IGovernorLifecycle(governor).execute(tB, _zeroes(tB.length), cB, hB);
        assertEq(IGovernorLifecycle(governor).state(idB), EXECUTED);
        assertTrue(probeB.marked(), "B's payload must have executed");
        assertFalse(probeA.marked(), "A's payload must never execute");
    }

    // ========== Proposal drivers ==========

    /// @dev The dependency proposal (stand-in for MGP-18): a single payload transaction.
    function _proposeDependency()
        internal
        returns (uint256 id, address[] memory targets, bytes[] memory calldatas, bytes32 descriptionHash)
    {
        targets = new address[](1);
        calldatas = new bytes[](1);
        targets[0] = address(probeA);
        calldatas[0] = abi.encodeCall(ExecutionProbe.mark, ());
        string memory description = "MGP-A: dependency (stand-in for MGP-18)";
        descriptionHash = keccak256(bytes(description));
        id = _propose(targets, calldatas, description);
    }

    /// @dev The dependent proposal, structured like the MGP-19 bundle:
    ///      transaction 0 is the guard call, the payload follows.
    function _proposeDependent(uint256 dependencyId)
        internal
        returns (uint256 id, address[] memory targets, bytes[] memory calldatas, bytes32 descriptionHash)
    {
        targets = new address[](2);
        calldatas = new bytes[](2);
        targets[0] = address(guard);
        calldatas[0] = abi.encodeCall(ProposalDependencyGuard.requireSettled, (governor, dependencyId));
        targets[1] = address(probeB);
        calldatas[1] = abi.encodeCall(ExecutionProbe.mark, ());
        string memory description = "MGP-B: dependent (stand-in for MGP-19)";
        descriptionHash = keccak256(bytes(description));
        id = _propose(targets, calldatas, description);
    }

    function _propose(address[] memory targets, bytes[] memory calldatas, string memory description)
        internal
        returns (uint256 id)
    {
        vm.prank(voter);
        id = IGovernorLifecycle(governor).propose(targets, _zeroes(targets.length), calldatas, description);
    }

    /// @dev Advances past the voting delay, casts the whale vote, advances past the voting period.
    function _voteAndSucceed(uint256 proposalId, uint8 support) internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = proposalId;
        _voteAll(ids, support);
    }

    /// @dev Same, for proposals sharing one voting window (proposed in the same block).
    function _voteAll(uint256[] memory ids, uint8 support) internal {
        IGovernorLifecycle gov = IGovernorLifecycle(governor);
        _advance(gov.votingDelay() + 1);
        for (uint256 i = 0; i < ids.length; i++) {
            assertEq(gov.state(ids[i]), ACTIVE, "proposal must be Active after the voting delay");

            // Sanity: the whale alone clears quorum, otherwise a For vote would silently end Defeated.
            uint256 snapshot = gov.proposalSnapshot(ids[i]);
            assertGe(
                gov.getVotes(voter, snapshot),
                gov.quorum(snapshot),
                "test voter's veMENTO does not clear quorum; increase LOCK_AMOUNT"
            );

            vm.prank(voter);
            gov.castVote(ids[i], support);
        }
        _advance(gov.votingPeriod() + 1);
        for (uint256 i = 0; i < ids.length; i++) {
            assertEq(
                gov.state(ids[i]),
                support == VOTE_FOR ? SUCCEEDED : DEFEATED,
                "unexpected proposal state after voting period"
            );
        }
    }

    // ========== Helpers ==========

    /// @dev Celo L2 has 1s blocks; Locking/Governor count blocks, the timelock counts
    ///      seconds, so both dimensions must advance together.
    function _advance(uint256 blocks_) internal {
        vm.roll(block.number + blocks_);
        vm.warp(block.timestamp + blocks_);
    }

    function _zeroes(uint256 length) internal pure returns (uint256[] memory values) {
        values = new uint256[](length);
    }
}
