<!-- markdownlint-disable MD036 MD041 -->

# MGP-19: Bringing Stable Asset Issuance Home to Celo Governance

_Posted to the Mento forum for discussion ahead of the on-chain proposal. The full specification — including the complete contract list, per-transaction details, and security considerations — will be attached to the on-chain MGP; this post covers the substance. All dollar amounts and reserve figures are as of 21 August 2026._

## TL;DR

This proposal brings governance of stable asset issuance home to Celo, where it began, and refocuses Mento Labs on the Mento FX DEX. Specifically, it:

1. **Transfers on-chain governance of the issuance protocol** (stable assets, elastic mint/burn, CDPs, and associated reserve parameters) **to Celo Governance.** The FX DEX, the MENTO token, and all other functions remain under Mento Governance.
2. **Confirms the AP Reserve Foundation as steward of the Mento Reserve and its revenue**, operating under standing principles: principal is never drawn, the yield split is a mandate set by governance and can be altered through Celo Governance, and the Foundation reports publicly every quarter.
3. **Ratifies a 2-year Reserve Operations Services Agreement** between the Mento Protocol Foundation and Mento Labs GmbH, covering reserve rebalancing as well as oracle relaying and the maintenance and monitoring of the oracle system. Consideration is **95% of the Reserve's remaining ETH-family holdings** (~322 ETH-equivalent, currently ~$771,000), drawn against the [MGP-15](https://governance.mento.org/proposals/9612927118152596303508629025446921820838883791262021704399949388476066345844) authorization. **No new allocation is requested.**
4. **Resolves the Reserve's CELO position** (~$3.47M): **90% returns to the Celo Community Fund**, and **10% remains in the Reserve as a staked asset of last resort**: excluded from rebalancing, staked to earn staking rewards, and drawable only under a recovery mechanism to be defined and approved by Celo Governance.

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

Everything else stays under Mento Governance: the FX DEX, the MENTO token, and the remaining scope of this DAO. Nothing changes operationally on day one — swaps, minting, burning and CDP operations continue exactly as before; what moves is the authority to change them, which Celo Governance then exercises through regular Celo governance proposals.

### 2. Reserve stewardship

The AP Reserve Foundation is authorized as steward of the Reserve's assets and revenue. As with MGP-15, this is an authorization: the Foundation determines the operational mechanics of asset management and yield distribution, bounded by standing principles that governance sets and can change:

- **Principal is untouchable.** Only yield is distributed; reserve collateral is not drawn for operations.
- **The yield split is a mandate from governance.** Yield is directed [XX]% to the AP Reserve Foundation to steward the issuance protocol and [XX]% to the Celo Community Fund. This mandate, like the rest of the Foundation's principles, can be altered at any time through Celo Governance. _(The Reserve currently generates ~$26-30k/month in gross yield.)_
- **The asset-of-last-resort CELO tranche and a ~5% ETH allocation sit outside the Foundation's discretionary set.**
- **Quarterly public reporting:** reserve composition, yield collected, distributions paid, and coverage ratio.

### 3. Reserve operations services agreement

Mento Labs GmbH continues as rebalancer and operator of record under a 24-month services agreement with the Mento Protocol Foundation, covering rebalance execution, peg-deviation response, infrastructure, incident response, and reporting — as well as operation of the oracle system the issuance protocol depends on: running and paying for the oracle relayers, and maintaining and monitoring the oracle and circuit-breaker stack.

**Consideration: 95% of the Reserve's remaining ETH-family holdings** (ETH, stETH, WETH), amounting to ~322 ETH-equivalent worth approximately **$771,000** at current prices, transferred as a single payment. The remaining 5% stays in the Reserve as its standing ETH allocation. The payment is drawn against the MGP-15 authorization (up to $3.75M from over-collateralization, with ETH on its approved asset list); this proposal converts part of that unspent authorization into a defined, term-limited contract with deliverables attached.

### 4. The CELO position

The Reserve holds ~$3.47M in CELO. Under this proposal:

- **90% (~$3.12M) is returned to the Celo Community Fund.**
- **10% (~$347k) remains in the Reserve as a staked asset of last resort**: staked to earn staking rewards (which accrue to the Reserve), excluded from the rebalancing set, subject to a no-sale covenant, and drawable only to make stablecoin holders whole if a primary reserve asset fails. No draw is automatic: the recovery mechanism will be defined in a follow-up Celo Governance proposal.

## Reserve impact

| Metric                                 | Assessment                                                                                                   |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Reserve assets today                   | ~$19.62M against ~$15.38M reserve debt (**~1.28×**)                                                          |
| After ETH-family transfer (§3, ~$771k) | **~1.23×**                                                                                                   |
| After 90% CELO return (§4, ~$3.12M)    | **~1.02×**                                                                                                   |
| Stable book alone (~$15.33M)           | **~1.00×**; outstanding stables are covered by stable assets alone, before counting the retained CELO or ETH |

## Timeline

1. Issuance governance transfer to Celo Governance.
2. Reserve Foundation assumes stewardship; first quarterly report within 90 days.
3. ETH-family transfer upon countersignature of the services agreement.
4. CELO split executed: 90% to the Community Fund, 10% staked and tagged as the asset-of-last-resort tranche.
5. Follow-up Celo Governance proposal defining the recovery mechanism.

## References

- [MGP-15: Mento Protocol Foundation Funding Request](https://forum.mento.org/t/mgp-15-mento-protocol-foundation-funding-request/104)
- [MGP-14: Mento V3 Deployment Phase 1](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103)
- [MGP-10: Restructuring the Mento Reserve](https://forum.mento.org/t/mgp-10-restructuring-the-mento-reserve-yield-on-mento-reserve-mento-funding/93)
- Mento Reserve Dashboard: [reserve.mento.org](https://reserve.mento.org/)
