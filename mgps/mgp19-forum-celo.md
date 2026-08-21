<!-- markdownlint-disable MD036 MD041 -->

# Bringing Mento Stable Asset Issuance Home to Celo Governance (MGP-19)

_Posted to the Celo forum to inform the Celo community: this proposal, if passed by Mento Governance as MGP-19, hands on-chain control of the Mento stable asset issuance protocol — the stablecoins, the reserve, the CDPs and their oracle layer — to Celo Governance and returns 90% of the Reserve's CELO to the Celo Community Fund. No Celo Governance action is required to receive the contracts; this post relates to an upcoming proxy vote in Celo Governance: the CGP itself carries no transactions, and its result directs how delegates vote on MGP-19 in Mento Governance with Celo Governance's MENTO allocation, recording the community's acceptance. The binding vote happens in Mento Governance; we are sharing it here first because Celo is the receiving side. All dollar amounts and reserve figures are as of 21 August 2026._

## TL;DR

This proposal brings governance of stable asset issuance home to Celo, where it began, and refocuses Mento Labs on the Mento FX DEX. Specifically, it:

1. **Transfers on-chain governance of the issuance protocol** (stable assets, elastic mint/burn, CDPs, and associated reserve parameters) **to Celo Governance.** The FX DEX, the MENTO token, and all other functions remain under Mento Governance.
2. **Confirms the AP Reserve Foundation as steward of the Mento Reserve and its revenue**, operating under standing principles: principal is never drawn, reserve yield funds the Foundation's stewardship mandate — so the protocol's operating costs are carried by the Foundation rather than by funding requests to the community — and the Foundation reports publicly every quarter. Like all of the Foundation's principles, the use of yield can be altered at any time through Celo Governance.
3. **Ratifies a 2-year Reserve Operations Services Agreement** between the Mento Protocol Foundation and Mento Labs GmbH, covering reserve rebalancing as well as oracle relaying and the maintenance and monitoring of the oracle system. Consideration is **95% of the Reserve's remaining ETH-family holdings** (~322 ETH-equivalent, currently ~$771,000), drawn against the [MGP-15](https://governance.mento.org/proposals/9612927118152596303508629025446921820838883791262021704399949388476066345844) authorization. **No new allocation is requested.**
4. **Resolves the Reserve's CELO position** (~$3.47M): **90% returns to the Celo Community Fund**, bringing home not just the asset but the authority over it — with Celo Governance, as the protocol's new owner, evaluating any reserve emergency case by case at its sole discretion. The remaining **10% stays in the Reserve as an asset of last resort**, removed from active rebalancing and staked for stCELO.

## Motivation

Mento is two products with different needs.

The **issuance protocol**'s natural long-term home is with a broad, established, decentralized community. That home is Celo Governance: it is where the protocol originated, where the stable assets live, and its community bears the consequences of how the protocol is governed.

The **FX DEX** (oracle-priced, zero-slippage stablecoin FX via FPMM pools, deployed under [MGP-14](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103)) is infrastructure with a clear market, best served by a focused operating team. Mento Labs will concentrate on it going forward, while remaining the Reserve's rebalancing operator under contract, so decentralized ownership does not mean operational neglect.

Decentralization is a path, and this proposal is a deliberate and important step forward on it, not only in where votes happen but in how the protocol is structured. It distributes authority, custody, and execution across distinct entities, each with a defined mandate and none able to act alone: **Celo Governance** holds ultimate authority over the issuance protocol; the **foundations** steward the protocol mandate and the Reserve's assets under principles that governance sets and can change; and **Mento Labs** executes reserve operations under a term-limited services agreement with deliverables attached.

Celo is where these assets live, not just where they trade. The Mento stables were created on Celo and have grown up with it: held in local wallets, moved in everyday payments, relied on by communities for whom a stablecoin is not a trading instrument but a working currency. Governance of the issuance protocol belongs with the people closest to it: a broad, established community that already governs the chain these assets call home.

The separation extends to leadership, and it has been taking shape gradually rather than overnight: **Bogdan Dumitru has taken the CEO position at Mento Labs**, consolidating leadership of the operating company around the team building the FX DEX, while **Markus Franke steps down from Mento Labs entirely to lead the Mento Protocol Foundation and the AP Reserve Foundation, and to serve as Head of Stablecoins at the Celo Core Co**, anchoring stewardship of the issuance protocol on the Celo ecosystem side. The natural endpoint of that evolution is this proposal. The people directing the protocol's stewardship and the people operating its infrastructure are no longer the same: authority, custody, and execution check one another, and no single party can move protocol assets on its own.

## What is being proposed

### 1. Issuance governance → Celo Governance

On-chain ownership and governance authority over the issuance contracts transfers from Mento Governance to Celo Governance: all 15 Mento stable assets, the direct reserve mint/burn path (Broker, BiPoolManager, Reserve), the V3 reserve issuance contracts, the CDP branches (GBPm, CHFm, JPYm), and the oracle and circuit-breaker layer that gates minting and burning. This covers stable asset parameters, CDP parameters, reserve composition policy, and admin roles on the issuance contracts.

Everything else stays under Mento Governance: the FX DEX, the MENTO token, and the remaining scope of the Mento DAO. Nothing changes operationally on day one — swaps, minting, burning and CDP operations continue exactly as before; what moves is the authority to change them, which Celo Governance then exercises through regular Celo governance proposals.

### 2. Reserve stewardship

The AP Reserve Foundation is authorized as steward of the Reserve's assets and revenue. As with MGP-15, this is an authorization: the Foundation determines the operational mechanics of asset management and yield distribution, bounded by standing principles that governance sets and can change:

- **Principal is untouchable.** Only yield is distributed; reserve collateral is not drawn for operations.
- **Reserve yield funds the stewardship mandate.** Yield accrues to the AP Reserve Foundation and covers the ongoing costs of running the issuance protocol: oracle operations, monitoring, audits, incident response, and reserve administration — so the protocol's operating budget no longer competes with community funds. Gross yield is modest — ~$26–30k/month today — next to the ~$3.1M in CELO and the protocol authority returning to the community under this proposal, and, like the rest of the Foundation's principles, its use can be altered at any time through Celo Governance.
- **The asset-of-last-resort stCELO tranche and a ~5% ETH allocation sit outside the Foundation's discretionary set.**
- **Quarterly public reporting:** reserve composition, yield collected, distributions paid, and coverage ratio.

### 3. Reserve operations services agreement

Mento Labs GmbH continues as rebalancer and operator of record under a 24-month services agreement with the Mento Protocol Foundation, covering rebalance execution, peg-deviation response, infrastructure, incident response, and reporting — as well as operation of the oracle system the issuance protocol depends on: running and paying for the oracle relayers, and maintaining and monitoring the oracle and circuit-breaker stack.

**Consideration: 95% of the Reserve's remaining ETH-family holdings** (ETH, stETH, WETH), amounting to ~322 ETH-equivalent worth approximately **$771,000** at current prices, transferred as a single payment. The remaining 5% stays in the Reserve as its standing ETH allocation. The payment is drawn against the MGP-15 authorization (up to $3.75M from over-collateralization, with ETH on its approved asset list); this proposal converts part of that unspent authorization into a defined, term-limited contract with deliverables attached.

### 4. The CELO position

The Reserve holds ~$3.47M in CELO — its oldest asset, and the one with the strongest claim to belong to the Celo community. That claim has shaped how the Reserve has handled it: in the interest of all CELO holders, the Reserve has been consistently reluctant to sell CELO, even when rebalancing logic alone might have argued for it. We recognize that decisions of that weight are more community-aligned sitting with Celo Governance than with a reserve operator. Under this proposal:

- **90% (~$3.12M) is returned to the Celo Community Fund.** With the asset, the backstop role comes home too: by accepting ownership of the stable assets and their reserve, Celo Governance commits to evaluating any emergency involving the protocol's reserve assets on a case-by-case basis, at its sole discretion — the Community Fund standing behind the issuance protocol as its reserve of last resort. Nothing is automatic and nothing is pre-committed. For context: in roughly six years of operation, the Reserve has never been underwater.
- **10% (~$347k) remains in the Reserve as an asset of last resort**: removed from the active rebalancing set and staked for stCELO, with staking rewards accruing to the Reserve.

## Reserve impact

Reserve debt — outstanding reserve-backed stables, net of reserve-held and irrecoverably lost supply — is **~$14.95M**. CDP-backed stables (GBPm, CHFm, JPYm) are backed by USDm locked in their troves, which is already counted in USDm's supply, so they add no further reserve debt. Against that debt the Reserve holds ~$19.61M today (~1.31×). After the transfers in this proposal, the protocol's backing builds up as follows:

| Backing layer                                                                             | Value    | Cumulative coverage |
| ----------------------------------------------------------------------------------------- | -------- | ------------------- |
| Stable book: reserve debt covered by stable assets alone                                  | ~$15.33M | **~1.03×**          |
| + retained buffers: standing ETH allocation (5%, §3) and CELO staked for stCELO (10%, §4) | ~$388k   | **~1.05×**          |
| + the Celo Community Fund (the 90% of CELO returned, §4)                                  | ~$3.12M  | **~1.26×**          |

_Note: the Community Fund layer is a last-resort backstop, not reserve collateral — any support is decided case by case at Celo Governance's sole discretion._

Every outstanding reserve-backed stablecoin is fully covered by stable assets alone; the retained buffers sit on top, and the Community Fund stands behind the protocol as its final backstop.

## Timeline

1. Issuance governance transfer to Celo Governance.
2. Reserve Foundation assumes stewardship; first quarterly report within 90 days.
3. ETH-family transfer upon countersignature of the services agreement.
4. CELO split executed: 90% transferred to the Celo Community Fund, 10% moved to the asset-of-last-resort bucket and staked for stCELO.

## References

- [MGP-15: Mento Protocol Foundation Funding Request](https://forum.mento.org/t/mgp-15-mento-protocol-foundation-funding-request/104)
- [MGP-14: Mento V3 Deployment Phase 1](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103)
- [MGP-10: Restructuring the Mento Reserve](https://forum.mento.org/t/mgp-10-restructuring-the-mento-reserve-yield-on-mento-reserve-mento-funding/93)
- Mento Reserve Dashboard: [reserve.mento.org](https://reserve.mento.org/)
