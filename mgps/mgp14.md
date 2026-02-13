# MGP-14: Mento V3 Deployment Phase 1

Author: Bogdan Dumitru
Created on: February 12, 2026 3:10 PM
Last update: February 13, 2026 4:11 PM
State: Draft

## TL;DR

Mento Labs is excited to begin deploying Mento V3 on Celo and Monad 🎉. In order to support the outlined flows, we ask the following of governance:

1. Temporarily transfer the `owner` role to a 4/7 multisig for the following contracts:
   - BiPoolManager
   - Circuit Breakers
   - USDm
   - EURm
   - GBPm

   This is necessary to orchestrate the rollout plan described in the proposal, with the understanding that we can execute only the actions described in this and subsequent proposals, and that any actions taken will be documented in the forum.

2. Permission to retain ownership over the to-be-deployed Monad contracts until we deploy a form of cross-chain governance, with the understanding that we will seek governance approval for any actions outside of normal operations.

The proposal outlines the underlying steps needed to execute Phase 1 of the Mento V3 deployment plan:

- On Celo:
  - Deploy FPMM-based DEX with VirtualPool wrapping the Mento V2 Pools
  - Migrate USDm/[USDC,USDT,axlUSDC] MentoV2 pools to Mento V3 FPMM Pools
  - Migrate the EURm/axlEUROC Mento V2 pool to a Mento V3 FPMM Pool
  - Migrate the USDm/EURm Mento V2 pool to a Mento V3 FPMM Pool
  - Migrate the GBPm token from Reserve- to CDP-backed
  - Migrate the USDm/GBPm Mento V2 pool to a Mento V3 FPMM Pool
- On Monad:
  - Deploy FPMM-based DEX
  - Deploy Wormhole-bridged USDm, EURm, and GBPm tokens on Monad
  - Deploy USDm/[USDC, aUSD] Mento V3 FPMM Pools
  - Deploy USDm/EURm and USDm/GBPm Mento V3 FPMM Pools

---

## Overview

Mento V3, the next evolution of our protocol, marks the transition from a decentralized stablecoin issuance protocol to a more holistic on-chain FX protocol through two major advancements:

- FPMM DEX: A new decentralised pool primitive that combines our oracle circuit breaker architecture with on-chain pool infrastructure to create a hybrid pool that follows off-chain oracle prices for efficient on-chain FX swaps. This pool will be used to swap Mento stables, and will also support 3rd-party stablecoin issuers.
- Mento Liquity V2: An evolution of Liquity V2, allowing the protocol to migrate its current experimental local currencies to a Liquity V2 deployment, where assets are collateralized by USDm and the reserve FX risk is mitigated through individual capital provider trove management. This will also allow users to represent long USDm, short XXXm positions.

Moving forward, we can think of Mento stables as falling into 3 categories:

- **Wrappers**: USDm and EURm fall in this category; they can be minted by using Reserve-whitelisted same-denomination stablecoins that exist in the ecosystem where Mento is deployed (e.g., USDT, USDC, AUSD, axlUSDC, and EURC)
- **CDP-Backed:** We will migrate GBPm into this category in this phase and continuously migrate other assets that meet strategic and liquidity requirements.
- **Reserve-backed:** Assets directly minted against the Reserve, like the current Mento V2 model. These assets will always have tighter global trading limits and can graduate to CDP-backed assets.

For the first Phase of Mento V3, we propose the following steps:

- **Deploy Mento V3 FPMM and periphery contracts to Celo and Monad,** including proxy/admin setup, oracle infrastructure, FPMM implementations and factory, routing/registry, liquidity strategies, ReserveV2, StableTokenV3, and Monad’s StableTokenSpoke.
- **Deploy the full Mento Liquity V2 setup on Celo** in a deliberately disabled state until the GBPm migration to the CDP model, ensuring it cannot be operated (by withholding the oracle price feed).
- **Deploy VirtualPools in our new Router. T**he VirtualPools wrap Mento V2 Pools, enabling swaps between Mento V2 and Mento V3 via our Router. This will be the entry point for swaps and will be used by our UI and 3rd-party aggregators going forward. It’s compatible with a classic Uniswap / Aerodrome Router.
- **Launch 1:1 FPMM pools on Celo** integrated with the Router while deprecating Mento V2 USDm-to-collateral pools by upgrading USDm, setting minter/burner roles, using BiPoolManager ownership to retire legacy exchanges, creating and seeding new 1:1 FPMM pools via FPMMFactory, updating VirtualPoolFactory, and ReserveLiquidityStrategy.
- **Deploy Wormhole NTT for USDm, EURm, and GBPm** and wire up bridging to Monad for USDm, EURm, and GBPm.
- **Migrate GBPm to a Mento Liquity V2 asset on Celo**. This entails multiple operations: the Reserve opens the foundational trove for the current outstanding GBPm supply and then burns it to serve as the base capital provider, an FPMM pool is deployed and configured for USDm/GBPm, and the V2 pool is deprecated.
- **Launch 1:1 FPMM pools on Monad** for all USDm-to-collateral pairs (USDC and aUSD).
- **Create USDm/GBPm FPMM Pool on Monad**

Given the operational complexity and timing of these steps, we’re requesting temporary ownership of certain core contracts to execute this migration through the end of the month. All operations that we perform will be thoroughly simulated, documented, and audited by external parties.

---

### Security Considerations

**Risk Assessment**

- Temporary centralization of ownership on a few core contracts to the Mento Labs Dev multisig.
- Limited scope: BiPoolManager, BreakerBox, USDm, EURm, GBPm.
- Duration: ~3 weeks in total, most critical ones will be returned sooner (USDm, EURm, GBPm).

**Safety Measures**

We will employ the same operational safety measures that we’ve been employing on the multisigs managing Mento Reserve funds for the last 3 years, with 0 incidents

**Transparency Commitments**

1. Public announcement before any transaction associated with this upgrade.
2. Technical details of changes are published on the forum.
3. Transaction hashes shared for community verification on the forum.

### Transaction Details

TBD

---
