# CommunityFundProxyVoter — design notes

_Status: parked prototype (2026-08-25). Contract: `src/CommunityFundProxyVoter.sol`; fork tests: `test/integration/CommunityFundProxyVoterFork.t.sol` (7 tests against the deployed Celo Governance and MentoGovernor on a Celo mainnet fork)._

## What it is

A permissionless relay that votes in Mento Governance with the veMENTO delegated to it — the Celo Community Fund's MENTO allocation — according to the outcome of a paired Celo Governance proposal (CGP). It replaces the human proxy-vote delegates (the CGP-0252 / CGP-0253 pattern) with a contract that votes in **both** directions: For when the CGP passes, Against when it is explicitly rejected, Abstain when it fails only on participation.

- `register(cgpId, targets, values, calldatas, description)` — trustless MGP↔CGP binding: recomputes the MGP id via `hashProposal` and parses the CGP id from a trailing `#celo-proposal-id=<id>` marker in the proposal description, which every veMENTO holder sees while voting. No registrar role.
- `recordPassed(mgpId)` — push path; callable only by Celo Governance as the CGP's single transaction. Governance only executes passing proposals, so execution is proof of passing.
- `snapshot(mgpId)` — pull path; anyone records the CGP outcome once its referendum is over.
- `castVote(mgpId)` — anyone, once: For / Against (no > yes) / Abstain (yes ≥ no but below participation quorum). In the Bravo counting module, Abstain affects neither quorum (only For votes count) nor outcome — it is an on-chain signal only, so Celo apathy never vetoes an MGP; only explicit rejection does.

The contract holds no funds and has no owner. The kill switch lives with the veMENTO lock owner — **Celo Governance owns the lock** (the approver multisig is only the current delegate), so onboarding the relay is one CGP transaction, `Locking.delegateTo(lockId, relay)`, and off-boarding is the same call pointed elsewhere.

## Verified on-chain facts the design rests on

Deployed Celo Governance implementation `0x40cac0be7e25b14e39f782d5b7e5c3076aa6c57a` (v1.5.1, verified source), proxy `0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972`:

- Stage durations: approval 1 day, referendum 7 days, execution 3 days.
- A **non-passing proposal never enters the Execution stage**: `_isDequeuedProposalExpired` marks it expired the moment its referendum ends, so `getProposalStage` reads Expiration. Only passing proposals read Execution.
- Expiry is not deletion. Deletion is lazy (`requireDequeuedAndDeleteExpired`, invoked by `execute`/`vote`/`approve` on that proposal), so a failed proposal's storage — `proposalExists`, `getVoteTotals`, `isProposalPassing` — survives until someone touches it. **`execute()` on an expired proposal does not revert; it deletes the record and returns false.**
- A proposal **cannot** be deleted while its referendum is running (deletion requires expiry).

Mento side: `votingDelay` 0, `votingPeriod` 691,200 blocks (8 days at 1s), quorum 2% of past total veMENTO supply (~105M → ~2.1M today), Bravo counting (quorum = For votes only; success = For > Against strictly).

## The griefing vector

Because a failed CGP is deleted by the first post-referendum touch, an adversary can call `execute(cgpId, index)` in the first block after the referendum ends, erasing the record before anyone snapshots. The relay then cannot settle and casts nothing (fail-safe — covered by `test_griefedFailedCgp_relayCastsNothing`). The damage is bounded: only the **Against** vote is suppressed, which matters only when someone else could carry Mento quorum (~2.1M veMENTO) without the fund. Mitigation in the base design: a keeper races to `snapshot()` at referendum end — the honest side needs one tx and the adversary must win a single-block race, every time.

## Proof-based hardening: settle even after the record is deleted

The deletion-timing rules above make the griefing structurally beatable with historical storage proofs:

**Key fact.** The record provably existed — with the final tally — at the *last block of the referendum*, because votes revert after the referendum ends and deletion is impossible before it ends. No adversary action, before or after, changes what that block's state root commits to.

**Anchor (verified live).** EIP-2935 is active on Celo: the history contract at `0x0000F90827F1C53a10cb7A02335B175320002935` (83 bytes of code) serves the last 8,191 block hashes ≈ **2.27 hours** at 1s blocks. (Confirmed by querying a hash 4,000 blocks back and matching it against the real header.) Plain `BLOCKHASH` gives only 256 blocks ≈ 4 minutes.

**Construction** — `snapshotWithProof(mgpId, headerB, headerB1, accountProof, storageProofs)`:

1. Verify `keccak(rlp(headerB1))` against the EIP-2935 contract (or a pinned hash, below).
2. Verify `headerB1.parentHash == keccak(rlp(headerB))` — consecutive blocks — and `timestamp(B) < referendumEnd <= timestamp(B+1)`. This proves B is the last referendum block.
3. Merkle-Patricia account proof of the Governance contract against `headerB.stateRoot` → its `storageRoot`; storage proofs for `proposals[cgpId]`:
   - `timestamp` (dequeue time — `referendumEnd = timestamp + approvalDuration + referendumDuration`, so the boundary check in step 2 is self-consistent with the proven state),
   - `votes.yes`, `votes.no`, `votes.abstain`,
   - `networkWeight`,
   - `approved` — requiring `approved == true` pins the proven struct to its post-dequeue phase (a never-dequeued proposal's creation timestamp could otherwise masquerade as a dequeue timestamp).
4. Recompute the verdict with the deployed formula: `support = yes / (yes + no + padding)` where `padding = max(0, participationQuorum × networkWeight − totalVotes)`, compared against the constitution threshold (default majority for a proposal whose only transaction is `recordPassed`); participation parameters can be proven from the same state or read live.

**Removing the 2.27-hour anchoring window.** Add a permissionless `pin(blockNumber)` that stores `blockhash(n)` permanently while still available. The keeper duty shrinks to one cheap, content-neutral tx within ~2 hours of each referendum end (nothing is gained by an adversary pinning first — a hash is a hash), after which the heavy proof can be submitted at any later time. `pin()` is ~10 lines and worth shipping even before the verifier exists: pinned hashes make proving possible retroactively once a verifier is deployed.

**Costs and couplings.**

- RLP header decoding + an MPT verifier (vendor Optimism's `MerkleTrie` or Lido's `MerklePatriciaProofVerifier`): roughly 300–500 lines, ~200–400k gas per proof.
- Couples the relay to Governance v1.5.1's storage layout (slot positions of the `proposals` mapping and the `Proposal` struct fields). Storage layouts are append-only in practice, but a Governance upgrade that reshuffles them would require a relay update.
- Recommendation: v1 ships `snapshot()` + `pin()`; `snapshotWithProof` is added if a contested proposal ever makes the griefing race real.

## Open items

- **Delegation CGP**: one transaction, `Locking.delegateTo(lockId, relay)` from Celo Governance (the lock owner). Off-boarding is symmetric.
- **Abstain policy**: abstain-on-turnout-failure (vs Against-on-any-failure) should be stated explicitly in the CGP that activates the relay.
- **Quorum inflation**: the Fund's lock counts toward total veMENTO supply, raising the absolute 2% quorum for *every* MGP (e.g., +50M locked ≈ +50% quorum). Size the delegation deliberately or pair with a `quorumNumerator` adjustment.
- **Lock decay**: a max-cliff lock holds full weight ~2 years, then needs a relock (owner action).
- **Timing discipline**: propose the MGP once the CGP result is known (staggered, as with MGP-18/19), or at least a day into the CGP referendum so the 8-day MGP window overlaps the result.
