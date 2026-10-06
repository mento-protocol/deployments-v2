## TL;DR

[MGP-18](https://forum.mento.org/t/137) replaced the time-windowed trading limits on the ten FX pools that remain on Mento V2 with a single global limit (LG) sized at each FX stable's supply on 31 August 2026, plus a 10% buffer. Supply has moved since: AUDm has used up its limit on both legs, so USDm -> AUDm swaps (minting AUDm) through the Broker revert today and the remaining AUDm -> USDm capacity is well below the AUDm supply, so full redemption is not possible either, while the XOFm, KESm, ZARm and CADm caps are now far larger than their supply needs. This proposal refreshes all twenty limits with the same method, sized from on-chain state at proposal creation, with one addition: no limit is set below 10,000 USD, so pools with a very small supply still get usable limits. It consists of 40 `Broker.configureTradingLimit` calls that reset each pool's accumulated net flow and set a new global-only limit on both legs.

Alongside this proposal (but outside of governance), the migration multisig that owns SortedOracles will raise the CELO/USD report expiry from 6 minutes to 1 day + 5 minutes, and Mento Labs will then move the CELO/USD oracle relayer from a per-minute to a daily schedule, in line with every other CELO/XXX gas feed since June 2026.

## Overview

The ten USDm/FX exchanges (AUDm, CADm, ZARm, COPm, BRLm, PHPm, GHSm, NGNm, KESm, XOFm) stay on the V2 model until they move to the CDP model. Their Broker trading limits are the lifetime global limits set by MGP-18, which executed on 31 August 2026 (block 76,288,502): FX leg = 1.1 x the FX supply at that time, USDm leg = the USD equivalent of that amount at the oracle rate of that time. The six collateral and 1:1 pools listed in MGP-18 have since been destroyed by the migration multisig, so these ten are the only V2 exchanges left.

Two things have changed since then (values read on Celo mainnet, chain ID 42220, block 78,975,146):

1. **AUDm supply grew past its limit.** AUDm supply is 8,603 against a global limit of 1,597 on the AUDm leg and 1,144 on the USDm leg, both effectively consumed (net flow -1,595 and +1,144). USDm -> AUDm swaps revert with `LG Exceeded`, and only the capacity still inside the limit can leave through the Broker. This is the `CUSD_CAUD_POOL_CAUD_LIMIT` alert visible on the monitoring dashboards.
2. **XOFm and KESm supply shrank**, so their caps (set at 21.1M XOFm and 23.4M KESm) are several times the current supply; the ZARm and CADm caps were already oversized relative to their small supplies.

This proposal re-sizes all twenty limits with the MGP-18 method from the supply and oracle rates at proposal creation, with a minimum of 10,000 USD per limit (see [How the limits work](#how-the-limits-work)). The script that builds the proposal, `script/migration/MGP20.sol` in the [deployments repository](https://github.com/mento-protocol/deployments-v2), reads every value from the chain when the proposal is created; nothing is hardcoded.

### Indicative values

The table below is the dry run of the script at block 79,393,729. These values are **indicative**. The final limits are computed from on-chain state at the moment the proposal is created and are the ones frozen into the proposal calldata; they will be published in `broadcast/MGP20.sol/42220/` together with the output of the payload checker (`script/actions/CheckMGP20Payload.s.sol`), which decodes the submitted calldata, binds it to the on-chain proposal and verifies that the frozen limits equal the 110% sizing, with the 10,000 USD minimum, at the recorded proposal-time block. The on-chain proposal description cannot be edited after submission, so the forum post, not this text, carries the final table.

| Pool      |  FX supply | FX net flow |  FX LG now |        FX LG proposed | USDm net flow | USDm LG now |    USDm LG proposed | Rate (USD per FX) |
| --------- | ---------: | ----------: | ---------: | --------------------: | ------------: | ----------: | ------------------: | ----------------: |
| USDm/AUDm |      8,603 |      -1,595 |      1,597 |   14,329 (increase)\* |         1,144 |       1,144 | 10,000 (increase)\* |            0.6979 |
| USDm/CADm |        971 |          -3 |     37,506 |     14,247 (reduce)\* |             2 |      27,284 |   10,000 (reduce)\* |            0.7019 |
| USDm/ZARm |     11,107 |        -152 |    895,818 |    165,373 (reduce)\* |             7 |      55,913 |   10,000 (reduce)\* |            0.0604 |
| USDm/COPm | 80,932,166 | -12,225,439 | 75,081,743 | 89,025,383 (increase) |         3,858 |      24,479 |   27,760 (increase) |            0.0003 |
| USDm/BRLm |  1,018,521 |     116,781 |  1,249,837 |    1,120,374 (reduce) |       -23,168 |     240,571 |    225,462 (reduce) |            0.2012 |
| USDm/PHPm |  1,616,088 |      -4,900 |  1,764,829 |  1,777,698 (increase) |            79 |      28,599 |     28,344 (reduce) |            0.0159 |
| USDm/GHSm |    276,934 |      -1,167 |    301,302 |    304,629 (increase) |            99 |      27,072 |     25,892 (reduce) |            0.0849 |
| USDm/NGNm | 67,876,095 |   3,718,104 | 81,435,214 |   74,663,705 (reduce) |        -2,686 |      60,395 |     56,354 (reduce) |            0.0007 |
| USDm/KESm |  8,797,270 |   1,549,166 | 23,420,075 |    9,676,998 (reduce) |       -11,805 |     180,850 |     74,554 (reduce) |            0.0077 |
| USDm/XOFm |  5,366,598 |  13,788,663 | 21,070,766 |    5,903,258 (reduce) |       -23,895 |      37,611 |     10,125 (reduce) |            0.0017 |

\* Set by the 10,000 USD minimum: the 1.1 x supply sizing is worth less than 10,000 USD for these pools (about 6,600, 750 and 740 USD respectively).

At block 79,393,729 this raises 6 limits and reduces 14 (whole tokens; "net flow" is the Broker's accumulated signed flow for that leg, negative when tokens left the pool to users).

The values are frozen into calldata at proposal creation, while supply and oracle rates keep moving through the 8-day voting period and the 2-day timelock. The 10% buffer covers moderate drift until execution. If the combined supply growth and FX appreciation of a pool exceed the buffer before execution, governance must refresh that pool's limits again. The execution owner named below monitors supply and oracle rates during voting and timelock with the payload checker, which reports for each pool whether the frozen limits still cover 100% of the current supply and its USD equivalent and whether the full supply can still exit in one swap.

**Execution owner:** TBD, to be named by Bayo before posting.

### How the limits work

The Broker enforces trading limits per pool and per token as a combination of a 5-minute window limit (L0), a 1-day window limit (L1) and a lifetime global limit (LG) on net flows. Since MGP-18 both tokens of each remaining pool carry a **global-only limit**, and this proposal keeps that shape:

- **FX token**: the token's current total supply x 1.1, rounded up to whole tokens.
- **USDm**: the USD equivalent of that buffered FX amount at the pool's current oracle rate, rounded up to whole USDm.
- **Minimum**: if that USD equivalent is below 10,000 USD, the USDm limit is set to 10,000 and the FX limit to the FX amount worth 10,000 USD at the same oracle rate (rounded up). Without it, pools with a very small supply, such as CADm and ZARm, would get limits worth a few hundred dollars. The 10% buffer already covers supply drift for larger pools; the minimum is new in this proposal.

Sizing the limits this way lets the proposal-time supply exit to USDm at the proposal-time oracle rate, within the 10% buffer. It does not guarantee full redemption at every future rate or supply. LG bounds the signed net flow from the reset state, so it also permits Broker-mediated issuance up to the same amount; it does not cap total supply or cumulative gross minting.

Each limit is **reset before being set**. The Broker preserves the accumulated net flow while a global limit stays configured, so the first transaction on each leg applies an empty configuration (no limits), which clears the counter, and the second applies the new global-only limit from a clean slate. The reset is the safety mechanism of this proposal, not cleanup: the XOFm leg currently carries a net flow of +13,788,663 XOFm against a proposed cap of 5,903,258; setting the smaller limit without clearing the counter would leave the pool over its limit and block XOFm redemptions immediately.

## Transaction Details

All governance transactions call `configureTradingLimit(bytes32 exchangeId, address token, Config config)` on the Broker proxy ([`0x777A8255cA72412f0d706dc03C9D1987306B4CaD`](https://celoscan.io/address/0x777A8255cA72412f0d706dc03C9D1987306B4CaD)).

The proposal contains **40 transactions**, 4 per exchange, repeated for each of the 10 exchanges, in this order:

| Target       | Function                | Parameters                                                                        |
| ------------ | ----------------------- | --------------------------------------------------------------------------------- |
| Broker Proxy | `configureTradingLimit` | exchangeId, FX token, empty config (reset net flow)                               |
| Broker Proxy | `configureTradingLimit` | exchangeId, FX token, global-only limit = supply x 1.1, at least 10,000 USD worth |
| Broker Proxy | `configureTradingLimit` | exchangeId, USDm, empty config (reset net flow)                                   |
| Broker Proxy | `configureTradingLimit` | exchangeId, USDm, global-only limit = USD equivalent x 1.1, at least 10,000 USDm  |

The affected exchanges (unchanged since MGP-18 and verified against the live BiPoolManager at block 78,975,146):

| Exchange  | Exchange ID                                                          |
| --------- | -------------------------------------------------------------------- |
| USDm/AUDm | `0xd580d237231109e6a96d67d82450611c610a805a26660c90281bdc0cd04a95c7` |
| USDm/CADm | `0x517ccc3bcab9f35e2e24143a0c1809068efc649f740846cfb6a1c5703735c1ee` |
| USDm/ZARm | `0x4206e101b13bf29e40b2bfed4cf167271c41677720f2ee786ac1bf5efac101cb` |
| USDm/COPm | `0x1c9378bd0973ff313a599d3effc654ba759f8ccca655ab6d6ce5bd39a212943b` |
| USDm/BRLm | `0xd11d52b973ddbb983cc2087aabcafd915fc3140cf9996aacc61db9710d1bde05` |
| USDm/PHPm | `0x7952984d7278ca3417febf52815c321984ac3147ced2c02bb6a02b0bcab08413` |
| USDm/GHSm | `0x3562f9d29eba092b857480a82b03375839c752346b9ebe93a57ab82410328187` |
| USDm/NGNm | `0x67a5122dab72931be57196e0abba81690461f327bc60fb98ca7eef0ac58906cc` |
| USDm/KESm | `0x89de88b8eb790de26f4649f543cb6893d93635c728ac857f0926e842fb0d298b` |
| USDm/XOFm | `0xc9664df358594c5eaf2f410ab371e2deb8b532ca26162d2bc36d99b8d174567b` |

The exact limit values are computed from on-chain state (token total supplies and oracle rates) when the proposal is created, by `script/migration/MGP20.sol` in the [deployments repository](https://github.com/mento-protocol/deployments-v2). Before submission the script requires that the BiPoolManager holds exactly these ten exchanges, that each pair matches exactly one live exchange, that both tokens have 18 decimals, that each pool's reference rate feed is the expected FX/USD feed with a nonzero median, and that both legs still carry the MGP-18 limit shape. After simulating the 40 calls it requires that both legs of every pool are global-only with the computed value and a zero net flow, and that the pool's entire FX supply can be swapped to USDm through the Broker in one transaction. The dry run can be reproduced by running the script in dry-run mode.

### Accompanying migration multisig and infrastructure operation

Separately from this proposal, and only after it has passed, two operational changes bring the CELO/USD oracle feed in line with the other CELO/XXX feeds:

1. **SortedOracles report expiry (migration multisig).** The migration multisig ([`0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458`](https://celoscan.io/address/0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458)), which owns SortedOracles ([`0xefb84935239dacdecf7c5ba76d8de40b077b7b33`](https://celoscan.io/address/0xefb84935239dacdecf7c5ba76d8de40b077b7b33)), calls `setTokenReportExpiry` for the CELO/USD rate feed (`0x765de816845861e75a25fca122bb6898b8b1282a`) to change its report expiry from 360 seconds (6 minutes) to 86,700 seconds (1 day + 5 minutes). Every other CELO/XXX feed (CELO/EUR, CELO/BRL, CELO/XOF, CELO/KES, CELO/PHP, CELO/COP, CELO/GHS, CELO/GBP, CELO/ZAR, CELO/CAD, CELO/AUD, CELO/CHF, CELO/JPY, CELO/NGN, CELO/ETH, CELO/XAUt) has reported with this expiry since June 2026; CELO/USD was the only one left at 6 minutes (block 78,975,146). The transaction is a single call, `SortedOracles.setTokenReportExpiry(0x765de816845861e75a25fca122bb6898b8b1282a, 86700)`, produced by `script/actions/UpdateCeloFeedsExpiry.s.sol`.
2. **Relayer schedule (Mento Labs infrastructure).** Once the expiry change has executed, the Cloud Scheduler job that triggers the CELO/USD Chainlink relayer (`0xF2dE36f13159B24F71b017ffDBbe2707E9276eeC`) moves from every minute to once a day at 00:00 UTC, the schedule the other CELO/XXX relayers have used since June 2026, and the automated signer refill treats it as a daily feed. This happens in the oracle-relayer repository, after the CELO/USD freshness and relay-failure alerting has been aligned with the other gas feeds.

**Why.** The CELO/USD feed only prices gas: Celo's `FeeCurrencyDirectory` ([`0x15F344b9E6c3Cb6F0376A36A64928b13F62C6276`](https://celoscan.io/address/0x15F344b9E6c3Cb6F0376A36A64928b13F62C6276)) reads `SortedOracles.medianRate` for CELO/USD to convert gas paid in USDm, exactly as it does for EURm, BRLm and the other Mento stables whose CELO/XXX feeds already report daily. No live V2 exchange references CELO/USD (the USDm/CELO pool was destroyed after MGP-18). Relaying a gas price every minute costs CELO and relayer operations without a protocol consumer that needs the frequency.

**Impact.** With a daily relay and a 1 day + 5 minute expiry, the CELO/USD price used for USDm gas can be up to about 24 hours old in normal operation, and up to about 48 hours old in the worst case the tolerances allow (an observation close to 24 hours old relayed, then no relay for a day). If daily relays fail repeatedly, the price keeps aging until a relay succeeds; the median keeps being served because SortedOracles never removes the last remaining report, so gas payments in USDm keep working while accuracy degrades with age. This is the same tolerance, and the same accepted trade-off, as for EURm, BRLm and the other stables since June 2026. The MedianDeltaBreaker on CELO/USD (3%, 30-minute cooldown) is unchanged.

**Sequencing.** Nothing changes before this proposal passes. The expiry is raised first: while the relayer keeps running every minute, the larger expiry only widens tolerances and has no visible effect. The schedule changes second, so the feed never reads as expired because of the cadence alone. Both steps can be reversed independently; the expiry can also stay at 1 day + 5 minutes if the schedule is reverted.

## Security Considerations

- The governance transactions only touch trading-limit configuration on the Broker for the ten existing, live exchanges. No ownership changes, no implementation upgrades, and no funds are involved. The payload is verified in three places: the pre- and post-checks inside the proposal script, the forge simulation of the full proposal, and the payload checker that decodes the submitted calldata, binds it to the on-chain proposal and replays it against a fork.
- The reset clears each leg's accumulated global net flow before applying the new limit. For AUDm this restores the full 1.1 x supply-sized headroom in both directions; for every pool it means the new bound applies from zero, including minting headroom up to the new cap. The limit bounds signed net flow from the reset state; it does not cap total supply or cumulative gross minting.
- For XOFm the reset is what makes a smaller cap possible: the current net flow (+13,788,663 XOFm at block 79,393,729) is larger than the proposed cap (5,903,258). The script applies the empty configuration first on every leg and the post-checks require a zero net flow after the set, so this ordering is enforced, not assumed.
- For pools sized by the 10,000 USD minimum, the minting headroom is up to 10,000 USD worth of the FX stable from the reset state, which is more than 10% of their current supply (CADm's supply is about 680 USD). The minimum is a fixed, small amount chosen so these pools stay usable; it does not grow with supply.
- The USDm limits use proposal-time oracle rates and supplies. Supply growth and FX appreciation share the 10% buffer until execution. If their combined movement exceeds it for a pool, that pool's full supply can no longer exit in one direction until governance refreshes the limit again; the execution owner monitors this through voting and timelock.
- The CELO/USD change is operational and reversible, executed by the migration multisig and Mento Labs only after this proposal passes. It widens the accepted staleness of the USDm gas price from minutes to about a day (bounds above) and makes relay-failure alerting a prerequisite of the schedule change. Ownership of SortedOracles and the other V2 contracts remains with the migration multisig, as since [MGP-14](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103), and will be transferred back to Mento Governance in a future MGP.
