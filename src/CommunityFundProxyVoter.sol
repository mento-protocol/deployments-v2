// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Read surface of the Celo Governance contract (celo-monorepo Governance v1.5.1).
interface ICeloGovernanceView {
    /// @return stage None(0) Queued(1) Approval(2) Referendum(3) Execution(4) Expiration(5).
    ///         Note the deployed expiry rule: a dequeued proposal that is past its referendum and
    ///         NOT passing reads Expiration — only passing proposals ever read Execution.
    function getProposalStage(uint256 proposalId) external view returns (uint8 stage);
    function isProposalPassing(uint256 proposalId) external view returns (bool);
    function getVoteTotals(uint256 proposalId) external view returns (uint256 yes, uint256 no, uint256 abstain);
    function proposalExists(uint256 proposalId) external view returns (bool);
}

/// @dev Voting surface of the MentoGovernor (OZ Governor + GovernorCompatibilityBravo).
interface IMentoGovernorVoting {
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /// @dev Reverts with "Governor: unknown proposal id" for proposals that were never made.
    function state(uint256 proposalId) external view returns (uint8);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
}

/**
 * @title CommunityFundProxyVoter
 * @notice Permissionless relay that votes in Mento Governance with the veMENTO delegated to it
 *         (the Celo Community Fund's MENTO allocation), according to the outcome of a paired
 *         Celo Governance proposal (CGP). PROTOTYPE.
 *
 *         Flow:
 *         1. An MGP is proposed on the MentoGovernor with a description that ends with the marker
 *            `#celo-proposal-id=<cgpId>`. Anyone calls {register} with the proposal preimage to
 *            bind the MGP to its CGP — the binding is taken from the proposal text itself, which
 *            every veMENTO holder sees while voting; no registrar role exists.
 *         2. The CGP outcome is captured by either path:
 *            - push: the CGP carries a single transaction, `recordPassed(mgpId)`. Celo Governance
 *              only executes passing proposals, so execution is proof of passing. This also covers
 *              the case where the passed CGP's record is deleted before anyone snapshots.
 *            - pull: anyone calls {snapshot} once the CGP's referendum is over. A passing proposal
 *              reads stage Execution (guaranteed 3-day window); a failed one reads Expiration with
 *              its storage surviving until someone touches it on the Governance contract.
 *         3. Anyone calls {castVote}: For if the CGP passed; Against if it was explicitly rejected
 *            (no > yes); Abstain if it failed on participation (yes >= no but below quorum) — so
 *            Celo apathy never vetoes an MGP with the Fund's full weight, only explicit rejection
 *            does. Abstain in the Bravo counting module affects neither quorum nor outcome; it is
 *            an on-chain signal only.
 *
 *         The contract holds no funds and has no owner. Celo Governance keeps the kill switch
 *         off-contract: it owns the veMENTO lock and can re-delegate it away at any time.
 */
contract CommunityFundProxyVoter {
    // Celo Governance stages
    uint8 internal constant STAGE_EXECUTION = 4;
    uint8 internal constant STAGE_EXPIRATION = 5;

    // Bravo vote support
    uint8 internal constant AGAINST = 0;
    uint8 internal constant FOR = 1;
    uint8 internal constant ABSTAIN = 2;

    /// @dev The MGP description must end with this marker followed by the decimal CGP id
    ///      (trailing whitespace is ignored).
    bytes internal constant MARKER = "#celo-proposal-id=";

    struct Outcome {
        bool settled;
        bool passed;
        /// @dev true when settled by the push path (CGP execution); vote totals are then unknown
        ///      here, but irrelevant: execution implies passing.
        bool pushed;
        uint256 yesVotes;
        uint256 noVotes;
    }

    ICeloGovernanceView public immutable celoGovernance;
    IMentoGovernorVoting public immutable mentoGovernor;

    /// @notice CGP id each registered MGP is bound to (0 = unregistered).
    mapping(uint256 mgpId => uint256 cgpId) public pairedCgp;
    mapping(uint256 mgpId => Outcome) internal _outcomes;
    /// @notice Whether the relay has cast its vote on an MGP.
    mapping(uint256 mgpId => bool) public voted;

    event Registered(uint256 indexed mgpId, uint256 indexed cgpId);
    event OutcomeRecorded(uint256 indexed mgpId, bool passed, bool pushed);
    event VoteCast(uint256 indexed mgpId, uint8 support);

    error MarkerNotFound();
    error CgpMismatch(uint256 fromDescription, uint256 provided);
    error AlreadyRegistered(uint256 mgpId, uint256 existingCgpId);
    error NotRegistered(uint256 mgpId);
    error AlreadySettled(uint256 mgpId);
    error NotSettled(uint256 mgpId);
    error CgpNotSettleable(uint256 cgpId, uint8 stage);
    error CgpRecordDeleted(uint256 cgpId);
    error AlreadyVoted(uint256 mgpId);
    error OnlyCeloGovernance();

    constructor(ICeloGovernanceView _celoGovernance, IMentoGovernorVoting _mentoGovernor) {
        celoGovernance = _celoGovernance;
        mentoGovernor = _mentoGovernor;
    }

    /// @notice Binds an existing MGP to the CGP id named in its description. Permissionless: the
    ///         caller supplies the proposal preimage; the id is recomputed and the CGP id is parsed
    ///         from the description's trailing `#celo-proposal-id=<id>` marker.
    /// @return mgpId The bound Mento proposal id.
    function register(
        uint256 cgpId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external returns (uint256 mgpId) {
        mgpId = mentoGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        mentoGovernor.state(mgpId); // reverts for proposals that were never made

        uint256 parsed = _parseCgpId(bytes(description));
        if (parsed != cgpId) revert CgpMismatch(parsed, cgpId);

        uint256 existing = pairedCgp[mgpId];
        if (existing != 0 && existing != cgpId) revert AlreadyRegistered(mgpId, existing);
        pairedCgp[mgpId] = cgpId;
        emit Registered(mgpId, cgpId);
    }

    /// @notice Push path: called by Celo Governance itself as the CGP's transaction. Execution is
    ///         proof the CGP passed, so no registration or snapshot is required for this path.
    function recordPassed(uint256 mgpId) external {
        if (msg.sender != address(celoGovernance)) revert OnlyCeloGovernance();
        if (voted[mgpId]) revert AlreadyVoted(mgpId);
        // Celo Governance is the ground truth; it may overwrite a pull-path outcome.
        _outcomes[mgpId] = Outcome({settled: true, passed: true, pushed: true, yesVotes: 0, noVotes: 0});
        emit OutcomeRecorded(mgpId, true, true);
    }

    /// @notice Pull path: records the paired CGP's final outcome once its referendum is over.
    ///         Callable by anyone. A passing CGP reads stage Execution (guaranteed for the 3-day
    ///         execution window); a failed or lapsed one reads Expiration and stays readable until
    ///         someone touches it on the Governance contract — so call this promptly after the
    ///         referendum ends.
    function snapshot(uint256 mgpId) external {
        if (_outcomes[mgpId].settled) revert AlreadySettled(mgpId);
        uint256 cgpId = pairedCgp[mgpId];
        if (cgpId == 0) revert NotRegistered(mgpId);

        uint8 stage = celoGovernance.getProposalStage(cgpId);
        if (stage < STAGE_EXECUTION) revert CgpNotSettleable(cgpId, stage); // referendum not over
        if (!celoGovernance.proposalExists(cgpId)) revert CgpRecordDeleted(cgpId);

        // Stage Execution implies passing under the deployed expiry rule; at Expiration the
        // surviving record answers directly (covers both rejection and a passed-but-lapsed CGP).
        bool passed = stage == STAGE_EXECUTION || celoGovernance.isProposalPassing(cgpId);
        (uint256 yes, uint256 no,) = celoGovernance.getVoteTotals(cgpId);
        _outcomes[mgpId] = Outcome({settled: true, passed: passed, pushed: false, yesVotes: yes, noVotes: no});
        emit OutcomeRecorded(mgpId, passed, false);
    }

    /// @notice Casts the relay's vote on the MGP according to the recorded CGP outcome.
    ///         Callable by anyone, once. The governor enforces that voting is open.
    function castVote(uint256 mgpId) external returns (uint8 support) {
        if (voted[mgpId]) revert AlreadyVoted(mgpId);
        Outcome storage o = _outcomes[mgpId];
        if (!o.settled) revert NotSettled(mgpId);
        voted[mgpId] = true;
        support = _support(o);
        mentoGovernor.castVote(mgpId, support);
        emit VoteCast(mgpId, support);
    }

    /// @notice The recorded outcome for an MGP.
    function outcomeOf(uint256 mgpId)
        external
        view
        returns (bool settled, bool passed, bool pushed, uint256 yesVotes, uint256 noVotes)
    {
        Outcome storage o = _outcomes[mgpId];
        return (o.settled, o.passed, o.pushed, o.yesVotes, o.noVotes);
    }

    /// @notice The support {castVote} would cast, given the recorded outcome.
    function plannedSupport(uint256 mgpId) external view returns (uint8) {
        Outcome storage o = _outcomes[mgpId];
        if (!o.settled) revert NotSettled(mgpId);
        return _support(o);
    }

    /// @dev passed -> For; explicit rejection (no > yes) -> Against; participation failure
    ///      (yes >= no but not passing) -> Abstain.
    function _support(Outcome storage o) internal view returns (uint8) {
        if (o.passed) return FOR;
        if (o.noVotes > o.yesVotes) return AGAINST;
        return ABSTAIN;
    }

    /// @dev Parses the decimal CGP id from the description's trailing `#celo-proposal-id=<id>`
    ///      marker, ignoring trailing whitespace. Parsing from the end keeps the scan O(marker).
    function _parseCgpId(bytes memory description) internal pure returns (uint256 id) {
        uint256 end = description.length;
        while (end > 0 && _isWhitespace(description[end - 1])) end--;

        uint256 start = end;
        while (start > 0 && description[start - 1] >= "0" && description[start - 1] <= "9") start--;
        if (start == end || start < MARKER.length) revert MarkerNotFound();

        for (uint256 i = 0; i < MARKER.length; i++) {
            if (description[start - MARKER.length + i] != MARKER[i]) revert MarkerNotFound();
        }
        for (uint256 i = start; i < end; i++) {
            id = id * 10 + uint8(description[i]) - uint8(bytes1("0"));
        }
    }

    function _isWhitespace(bytes1 c) internal pure returns (bool) {
        return c == " " || c == "\n" || c == "\r" || c == "\t";
    }
}
