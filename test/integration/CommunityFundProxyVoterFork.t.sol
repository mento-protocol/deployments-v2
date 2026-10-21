// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {CommunityFundProxyVoter, ICeloGovernanceView, IMentoGovernorVoting} from "src/CommunityFundProxyVoter.sol";

/// @dev Lifecycle surface of the deployed Celo Governance (celo-monorepo v1.5.1).
interface ICeloGovernanceLifecycle {
    function propose(
        uint256[] calldata values,
        address[] calldata destinations,
        bytes calldata data,
        uint256[] calldata dataLengths,
        string calldata descriptionUrl
    ) external payable returns (uint256);

    function approve(uint256 proposalId, uint256 index) external returns (bool);

    /// @dev VoteValue: None(0) Abstain(1) No(2) Yes(3).
    function vote(uint256 proposalId, uint256 index, uint8 value) external returns (bool);

    function execute(uint256 proposalId, uint256 index) external returns (bool);

    function dequeueProposalsIfReady() external;

    function getDequeue() external view returns (uint256[] memory);

    function getProposalStage(uint256 proposalId) external view returns (uint8);

    function isProposalPassing(uint256 proposalId) external view returns (bool);

    function proposalExists(uint256 proposalId) external view returns (bool);

    function stageDurations() external view returns (uint256 approval, uint256 referendum, uint256 execution);

    function approver() external view returns (address);

    function minDeposit() external view returns (uint256);

    function dequeueFrequency() external view returns (uint256);

    function lastDequeue() external view returns (uint256);
}

interface ICeloRegistryView {
    function getAddressForString(string calldata identifier) external view returns (address);
}

interface IAccountsMin {
    function createAccount() external returns (bool);
}

interface ILockedGoldMin {
    function getAccountTotalGovernanceVotingPower(address account) external view returns (uint256);
}

/// @dev Lifecycle surface of the deployed MentoGovernor used to drive test MGPs.
interface IMentoGovTest {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function state(uint256 proposalId) external view returns (uint8);

    function votingPeriod() external view returns (uint256);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function quorum(uint256 blockNumber) external view returns (uint256);

    function getVotes(address account, uint256 blockNumber) external view returns (uint256);

    /// @dev GovernorCompatibilityBravo tallies.
    function proposals(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool canceled,
            bool executed
        );
}

interface ILockingTest {
    function token() external view returns (address);

    function lock(address account, address _delegate, uint96 amount, uint32 slopePeriod, uint32 cliff)
        external
        returns (uint256);
}

interface IERC20ApproveMin {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract VotePayloadProbe {
    bool public marked;

    function mark() external {
        marked = true;
    }
}

/**
 * @title CommunityFundProxyVoterForkTest
 * @notice Fork tests for the CommunityFundProxyVoter prototype against the actually deployed
 *         Celo Governance (0xD533…7972) and MentoGovernor on Celo mainnet.
 *
 *         Each test drives a REAL CGP through the deployed Governance pipeline
 *         (propose -> dequeue -> approve -> referendum vote -> settle) and a REAL MGP through
 *         the MentoGovernor (real veMENTO delegated to the relay via Locking), then verifies the
 *         relay's outcome capture and vote:
 *         - passed CGP, pull path (Execution-stage snapshot) -> For
 *         - passed CGP, push path (the CGP's own recordPassed transaction, actually executed
 *           by Celo Governance) -> For
 *         - explicitly rejected CGP (Expiration stage, record surviving) -> Against
 *         - participation-failure CGP (yes >= no below quorum) -> Abstain
 *         - failed CGP whose record is griefed away before snapshot -> relay cannot settle,
 *           casts nothing (fail-safe)
 *
 *         The only mocked call is LockedGold.getAccountTotalGovernanceVotingPower for the test's
 *         CELO voter — everything else (stage machine, expiry rule, participation math, deletion,
 *         Bravo counting, veMENTO weights) runs on the real deployed contracts.
 *
 *         Environment: FORK_URL must point at a Celo mainnet RPC (chain 42220).
 */
contract CommunityFundProxyVoterForkTest is V3IntegrationBase {
    address internal constant CELO_CORE_REGISTRY = 0x000000000000000000000000000000000000ce10;

    // Celo Governance stages
    uint8 internal constant STAGE_EXECUTION = 4;
    uint8 internal constant STAGE_EXPIRATION = 5;
    // Celo VoteValue
    uint8 internal constant CELO_VOTE_NO = 2;
    uint8 internal constant CELO_VOTE_YES = 3;
    // Bravo support
    uint8 internal constant AGAINST = 0;
    uint8 internal constant FOR = 1;
    uint8 internal constant ABSTAIN = 2;
    // Mento proposal states
    uint8 internal constant SUCCEEDED = 4;
    uint8 internal constant DEFEATED = 3;

    uint96 internal constant RELAY_DELEGATION = 50_000_000e18;
    uint96 internal constant PROPOSER_LOCK = 10_000_000e18;
    uint256 internal constant CELO_WHALE_WEIGHT = 40_000_000e18;
    uint256 internal constant CELO_DUST_WEIGHT = 1_000e18;

    ICeloGovernanceLifecycle internal celoGov;
    address internal accountsContract;
    address internal lockedGold;

    address internal mentoGovernor;
    address internal locking;

    CommunityFundProxyVoter internal relay;
    VotePayloadProbe internal probe;

    address internal celoProposer = makeAddr("celoProposer");
    address internal celoVoter = makeAddr("celoVoter");
    address internal mentoProposer = makeAddr("mentoProposer");
    address internal lockOwner = makeAddr("communityFundLockOwner");

    function setUp() public override {
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }

        string memory namespace = vm.envOr("NAMESPACE", string("default"));
        registry = new Registry(namespace, ".treb/registry.json", ".treb/addressbook.json");

        celoGov = ICeloGovernanceLifecycle(ICeloRegistryView(CELO_CORE_REGISTRY).getAddressForString("Governance"));
        accountsContract = ICeloRegistryView(CELO_CORE_REGISTRY).getAddressForString("Accounts");
        lockedGold = ICeloRegistryView(CELO_CORE_REGISTRY).getAddressForString("LockedGold");

        mentoGovernor = lookupProxyOrFail("MentoGovernor");
        locking = lookupProxyOrFail("Locking");

        relay = new CommunityFundProxyVoter(ICeloGovernanceView(address(celoGov)), IMentoGovernorVoting(mentoGovernor));
        probe = new VotePayloadProbe();

        // Celo-side voter must be a registered account to vote on governance proposals.
        vm.prank(celoVoter);
        IAccountsMin(accountsContract).createAccount();

        // Mento side: real veMENTO. One lock delegated to the relay (the Community Fund
        // delegation this design proposes) and one for the MGP proposer's threshold.
        address mento = ILockingTest(locking).token();
        deal(mento, lockOwner, uint256(RELAY_DELEGATION) + PROPOSER_LOCK);
        vm.startPrank(lockOwner);
        IERC20ApproveMin(mento).approve(locking, uint256(RELAY_DELEGATION) + PROPOSER_LOCK);
        // max cliff keeps the bias flat through the multi-week warps these tests perform
        ILockingTest(locking).lock(lockOwner, address(relay), RELAY_DELEGATION, 104, 103);
        ILockingTest(locking).lock(mentoProposer, mentoProposer, PROPOSER_LOCK, 104, 103);
        vm.stopPrank();
        _advance(2);
    }

    // ========== Registration ==========

    function test_register_bindsMgpToMarkedCgp() public {
        uint256 cgpId = 424242; // registration binds by text; reality is checked at snapshot time
        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);

        uint256 returned = relay.register(cgpId, t, _zeroes(t.length), c, d);
        assertEq(returned, mgpId);
        assertEq(relay.pairedCgp(mgpId), cgpId);

        // mismatched id refused
        vm.expectRevert(abi.encodeWithSelector(CommunityFundProxyVoter.CgpMismatch.selector, cgpId, cgpId + 1));
        relay.register(cgpId + 1, t, _zeroes(t.length), c, d);

        // unmarked description refused
        string memory bare = "MGP without a marker";
        vm.prank(mentoProposer);
        IMentoGovTest(mentoGovernor).propose(t, _zeroes(t.length), c, bare);
        vm.expectRevert(CommunityFundProxyVoter.MarkerNotFound.selector);
        relay.register(cgpId, t, _zeroes(t.length), c, bare);

        // never-proposed MGP refused by the governor itself
        vm.expectRevert("Governor: unknown proposal id");
        relay.register(cgpId, t, _zeroes(t.length), c, "no such proposal #celo-proposal-id=424242");
    }

    // ========== Passed CGP ==========

    /// @notice Pull path: CGP passes its referendum, relay snapshots during the Execution stage
    ///         and casts For with the full delegated weight.
    function test_passedCgp_pullPath_votesFor() public {
        (uint256 cgpId, uint256 index) = _proposeCgp(address(0), "");
        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_YES, CELO_WHALE_WEIGHT);
        _endReferendum();

        assertEq(celoGov.getProposalStage(cgpId), STAGE_EXECUTION, "passing CGP must read Execution");
        assertTrue(celoGov.isProposalPassing(cgpId));

        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);
        relay.register(cgpId, t, _zeroes(t.length), c, d);
        relay.snapshot(mgpId);
        assertEq(relay.plannedSupport(mgpId), FOR);

        relay.castVote(mgpId);
        uint256 weight = _relayWeight(mgpId);
        assertGt(weight, 0);
        (,,,,, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes,,) =
            IMentoGovTest(mentoGovernor).proposals(mgpId);
        assertEq(forVotes, weight, "relay must vote For with its full delegated weight");
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);

        // the relay's For alone carries quorum (2% of supply) and the MGP succeeds
        _advance(IMentoGovTest(mentoGovernor).votingPeriod() + 1);
        assertEq(IMentoGovTest(mentoGovernor).state(mgpId), SUCCEEDED);
    }

    /// @notice Push path, end to end: the CGP's own transaction is recordPassed(mgpId) and is
    ///         actually executed by the deployed Celo Governance contract.
    function test_passedCgp_pushPath_executedCgpVotesFor() public {
        // The MGP id is deterministic, so the CGP can carry it before the MGP is proposed —
        // exactly as in the real flow, where the CGP is written first.
        (address[] memory t, bytes[] memory c) = _mgpPayload();
        (uint256 cgpId, uint256 index) = _proposeCgpExpectingPayload(t, c);

        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_YES, CELO_WHALE_WEIGHT);
        _endReferendum();
        assertEq(celoGov.getProposalStage(cgpId), STAGE_EXECUTION);

        // anyone executes the passed CGP on the real Governance contract
        celoGov.execute(cgpId, index);
        assertFalse(celoGov.proposalExists(cgpId), "execution deletes the CGP record");

        uint256 mgpId = _expectedMgpId(cgpId, t, c);
        (bool settled, bool passed, bool pushed,,) = relay.outcomeOf(mgpId);
        assertTrue(settled && passed && pushed, "execution must have pushed the outcome");

        // now the MGP is proposed (staggered, as in the real process) and the relay votes For —
        // no registration or snapshot needed on the push path
        (uint256 proposedId,,,) = _proposeMgp(cgpId);
        assertEq(proposedId, mgpId, "precomputed MGP id must match");

        relay.castVote(mgpId);
        (,,,,, uint256 forVotes,,,,) = IMentoGovTest(mentoGovernor).proposals(mgpId);
        assertEq(forVotes, _relayWeight(mgpId));
    }

    // ========== Failed CGP ==========

    /// @notice Explicit rejection: No-majority. The failed CGP reads Expiration with its record
    ///         surviving; the relay snapshots it and casts Against.
    function test_rejectedCgp_votesAgainst() public {
        (uint256 cgpId, uint256 index) = _proposeCgp(address(0), "");
        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_NO, CELO_WHALE_WEIGHT);
        _endReferendum();

        assertEq(celoGov.getProposalStage(cgpId), STAGE_EXPIRATION, "failed CGP reads Expiration, not Execution");
        assertTrue(celoGov.proposalExists(cgpId), "record survives until touched");
        assertFalse(celoGov.isProposalPassing(cgpId));

        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);
        relay.register(cgpId, t, _zeroes(t.length), c, d);
        relay.snapshot(mgpId);
        assertEq(relay.plannedSupport(mgpId), AGAINST);

        relay.castVote(mgpId);
        (,,,,, uint256 forVotes, uint256 againstVotes,,,) = IMentoGovTest(mentoGovernor).proposals(mgpId);
        assertEq(againstVotes, _relayWeight(mgpId), "relay must veto an explicitly rejected CGP");
        assertEq(forVotes, 0);

        _advance(IMentoGovTest(mentoGovernor).votingPeriod() + 1);
        assertEq(IMentoGovTest(mentoGovernor).state(mgpId), DEFEATED);
    }

    /// @notice Participation failure: yes >= no but below the participation quorum. The relay
    ///         abstains — a signal, not a veto, and no quorum contribution in Bravo counting.
    function test_turnoutFailedCgp_abstains() public {
        (uint256 cgpId, uint256 index) = _proposeCgp(address(0), "");
        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_YES, CELO_DUST_WEIGHT);
        _endReferendum();

        assertEq(celoGov.getProposalStage(cgpId), STAGE_EXPIRATION);
        assertFalse(celoGov.isProposalPassing(cgpId), "dust yes vote must fail participation");

        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);
        relay.register(cgpId, t, _zeroes(t.length), c, d);
        relay.snapshot(mgpId);
        assertEq(relay.plannedSupport(mgpId), ABSTAIN);

        relay.castVote(mgpId);
        (,,,,, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes,,) =
            IMentoGovTest(mentoGovernor).proposals(mgpId);
        assertEq(abstainVotes, _relayWeight(mgpId));
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);

        // abstain does not carry quorum: the MGP dies without other For votes
        _advance(IMentoGovTest(mentoGovernor).votingPeriod() + 1);
        assertEq(IMentoGovTest(mentoGovernor).state(mgpId), DEFEATED);
    }

    /// @notice Griefing: anyone can touch an expired (failed) CGP on the Governance contract,
    ///         deleting its record. The relay then cannot settle and casts nothing — fail-safe.
    function test_griefedFailedCgp_relayCastsNothing() public {
        (uint256 cgpId, uint256 index) = _proposeCgp(address(0), "");
        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_NO, CELO_WHALE_WEIGHT);
        _endReferendum();

        // the griefer wins the race: execute() on an expired proposal deletes it, returns false
        celoGov.execute(cgpId, index);
        assertFalse(celoGov.proposalExists(cgpId));

        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);
        relay.register(cgpId, t, _zeroes(t.length), c, d);

        vm.expectRevert(abi.encodeWithSelector(CommunityFundProxyVoter.CgpRecordDeleted.selector, cgpId));
        relay.snapshot(mgpId);
        vm.expectRevert(abi.encodeWithSelector(CommunityFundProxyVoter.NotSettled.selector, mgpId));
        relay.castVote(mgpId);
    }

    /// @notice The outcome is not readable before the referendum is over.
    function test_snapshot_revertsWhileReferendumRunning() public {
        (uint256 cgpId, uint256 index) = _proposeCgp(address(0), "");
        _approveCgp(cgpId, index);
        _voteCgp(cgpId, index, CELO_VOTE_YES, CELO_WHALE_WEIGHT);

        (uint256 mgpId, address[] memory t, bytes[] memory c, string memory d) = _proposeMgp(cgpId);
        relay.register(cgpId, t, _zeroes(t.length), c, d);

        uint8 stage = celoGov.getProposalStage(cgpId);
        vm.expectRevert(abi.encodeWithSelector(CommunityFundProxyVoter.CgpNotSettleable.selector, cgpId, stage));
        relay.snapshot(mgpId);
    }

    // ========== CGP drivers (real deployed Celo Governance) ==========

    /// @dev Proposes a CGP (empty payload unless dest is set) and dequeues it.
    function _proposeCgp(address dest, bytes memory cdata) internal returns (uint256 cgpId, uint256 index) {
        uint256[] memory values;
        address[] memory destinations;
        uint256[] memory dataLengths;
        bytes memory data;
        if (dest != address(0)) {
            values = new uint256[](1);
            destinations = new address[](1);
            dataLengths = new uint256[](1);
            destinations[0] = dest;
            dataLengths[0] = cdata.length;
            data = cdata;
        }

        uint256 deposit = celoGov.minDeposit();
        vm.deal(celoProposer, deposit);
        vm.prank(celoProposer);
        cgpId =
            celoGov.propose{value: deposit}(values, destinations, data, dataLengths, "https://forum.celo.org/t/test");

        index = _dequeue(cgpId);
    }

    /// @dev Propose-first variant for the push path: the CGP id is only known after proposing, and
    ///      the recordPassed payload needs the MGP id, which depends on the CGP id (via the
    ///      description marker). Solved by proposing with a payload computed from the predicted id:
    ///      Governance ids are sequential (proposalCount + 1), observed by a zero-cost probe.
    function _proposeCgpExpectingPayload(address[] memory t, bytes[] memory c)
        internal
        returns (uint256 cgpId, uint256 index)
    {
        // predict the id with a throwaway proposal, then use predicted+1 for the real one
        (uint256 probeId,) = _proposeCgp(address(0), "");
        uint256 predictedId = probeId + 1;
        uint256 mgpId = _expectedMgpId(predictedId, t, c);
        (cgpId, index) = _proposeCgp(address(relay), abi.encodeCall(CommunityFundProxyVoter.recordPassed, (mgpId)));
        require(cgpId == predictedId, "CGP id prediction failed");
    }

    function _dequeue(uint256 cgpId) internal returns (uint256 index) {
        for (uint256 round = 0; round < 15; round++) {
            uint256[] memory dequeued = celoGov.getDequeue();
            for (uint256 i = 0; i < dequeued.length; i++) {
                if (dequeued[i] == cgpId) return i;
            }
            uint256 next = celoGov.lastDequeue() + celoGov.dequeueFrequency() + 1;
            _advance(next > block.timestamp ? next - block.timestamp : 1);
            celoGov.dequeueProposalsIfReady();
        }
        revert("CGP did not dequeue in 15 rounds; mainnet queue too crowded");
    }

    function _approveCgp(uint256 cgpId, uint256 index) internal {
        (uint256 approvalDuration,,) = celoGov.stageDurations();
        _advance(approvalDuration + 1); // approval happens once the proposal is in Referendum
        vm.prank(celoGov.approver());
        celoGov.approve(cgpId, index);
    }

    /// @dev The single mock in these tests: the CELO voter's locked-gold voting power.
    function _voteCgp(uint256 cgpId, uint256 index, uint8 value, uint256 weight) internal {
        vm.mockCall(
            lockedGold,
            abi.encodeWithSelector(ILockedGoldMin.getAccountTotalGovernanceVotingPower.selector, celoVoter),
            abi.encode(weight)
        );
        vm.prank(celoVoter);
        celoGov.vote(cgpId, index, value);
        vm.clearMockedCalls();
    }

    function _endReferendum() internal {
        (, uint256 referendumDuration,) = celoGov.stageDurations();
        _advance(referendumDuration); // already approvalDuration+1 past dequeue -> lands in the execution window
    }

    // ========== MGP drivers (real deployed MentoGovernor) ==========

    function _mgpPayload() internal view returns (address[] memory targets, bytes[] memory calldatas) {
        targets = new address[](1);
        calldatas = new bytes[](1);
        targets[0] = address(probe);
        calldatas[0] = abi.encodeCall(VotePayloadProbe.mark, ());
    }

    function _mgpDescription(uint256 cgpId) internal pure returns (string memory) {
        return string.concat(
            "MGP-test: proxy-voted proposal\n\nSee the paired Celo proposal.\n\n#celo-proposal-id=", vm.toString(cgpId)
        );
    }

    function _expectedMgpId(uint256 cgpId, address[] memory t, bytes[] memory c) internal view returns (uint256) {
        return IMentoGovernorVoting(mentoGovernor)
            .hashProposal(t, _zeroes(t.length), c, keccak256(bytes(_mgpDescription(cgpId))));
    }

    function _proposeMgp(uint256 cgpId)
        internal
        returns (uint256 mgpId, address[] memory targets, bytes[] memory calldatas, string memory description)
    {
        (targets, calldatas) = _mgpPayload();
        description = _mgpDescription(cgpId);
        vm.prank(mentoProposer);
        mgpId = IMentoGovTest(mentoGovernor).propose(targets, _zeroes(targets.length), calldatas, description);
        _advance(1); // votingDelay is 0: one block puts the proposal in Active
    }

    function _relayWeight(uint256 mgpId) internal view returns (uint256) {
        uint256 snapshotBlock = IMentoGovTest(mentoGovernor).proposalSnapshot(mgpId);
        return IMentoGovTest(mentoGovernor).getVotes(address(relay), snapshotBlock);
    }

    // ========== Helpers ==========

    /// @dev Celo L2 has 1s blocks; Locking/MentoGovernor count blocks, both governance timelocks
    ///      count seconds, so advance both dimensions together.
    function _advance(uint256 blocks_) internal {
        vm.roll(block.number + blocks_);
        vm.warp(block.timestamp + blocks_);
    }

    function _zeroes(uint256 length) internal pure returns (uint256[] memory values) {
        values = new uint256[](length);
    }
}
