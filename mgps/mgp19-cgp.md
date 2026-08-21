<!-- markdownlint-disable MD036 MD041 -->

# CGP-[XX]: Accepting Governance of the Mento Stable Asset Issuance Protocol

_Signaling (proxy) proposal — no on-chain transactions are attached. This document summarizes MGP-19 for the Celo community; the MGP-19 proposal text as voted on in Mento Governance is the final and authoritative reference for this proposal, and prevails over this summary in case of any discrepancy. All dollar amounts are as of 21 August 2026._

## Summary

Mento Governance proposal [MGP-19: Bringing Stable Asset Issuance Home to Celo Governance] transfers on-chain ownership of the Mento stable asset issuance protocol to Celo Governance and returns 90% of the Mento Reserve's CELO position (~$3.12M) to the Celo Community Fund. This proposal records the Celo community's acceptance of that transfer and of the governance role that comes with it: its result directs how delegates vote on MGP-19 in Mento Governance with Celo Governance's MENTO allocation. The contract handover executes from the Mento side once MGP-19 passes; no Celo Governance transaction is required to receive it.

## Background

The Mento stables were created on Celo and have grown up with it: held in local wallets, moved in everyday payments, relied on by communities for whom a stablecoin is a working currency. MGP-19 returns governance of their issuance to the community closest to them, while Mento Labs refocuses on the Mento FX DEX and continues to operate the Reserve under a term-limited services agreement.

## What Celo Governance receives

- **Ownership and upgrade authority over the issuance protocol**: all 15 Mento stable assets (USDm, EURm, GBPm, CHFm, JPYm, BRLm, XOFm, KESm, PHPm, COPm, GHSm, ZARm, CADm, AUDm, NGNm), the reserve mint/burn path (Broker, BiPoolManager, Reserve, ReserveV2 and its liquidity strategies), the CDP branches, and the oracle and circuit-breaker layer that gates minting and burning. Future changes go through regular Celo Governance proposals.
- **90% of the Reserve's CELO position (~$3.12M)**, transferred to the Celo Community Fund.
- **Authority over the AP Reserve Foundation's standing principles**, including the use of reserve yield, which can be altered at any time through Celo Governance.

## What acceptance entails

- By accepting ownership of the stable assets and their reserve, Celo Governance commits to evaluating any emergency involving the protocol's reserve assets on a case-by-case basis, at its sole discretion — the Community Fund standing behind the issuance protocol as its reserve of last resort. Nothing is automatic and nothing is pre-committed. For context: in roughly six years of operation, the Reserve has never been underwater.
- Day-to-day operations remain delegated: the AP Reserve Foundation stewards the Reserve under standing principles Celo Governance can change (principal never drawn, quarterly public reporting), and Mento Labs GmbH operates rebalancing and the oracle system under a 2-year services agreement with the Mento Protocol Foundation.
- 10% of the Reserve's CELO (~$347k) remains in the Reserve as an asset of last resort, removed from active rebalancing and staked for stCELO.

## Specification

This is a proxy (signaling) proposal with no execution payload: the CGP itself does not vote. Its outcome directs the delegates of Celo Governance's MENTO allocation, who cast the corresponding vote on MGP-19 in Mento Governance. On approval of MGP-19 by Mento Governance, ownership of the issuance contracts is transferred on-chain to the Celo Governance contract (`0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972`) by the Mento Governance timelock and the Mento Labs migration multisig, and the CELO transfer to the Community Fund is executed as described in MGP-19.

## References

- **MGP-19 proposal text (authoritative reference): [link TBD]**
- MGP-19 forum post (Mento): [link TBD]
- MGP-19 forum post (Celo): [link TBD]
- Mento Reserve Dashboard: [reserve.mento.org](https://reserve.mento.org/)
