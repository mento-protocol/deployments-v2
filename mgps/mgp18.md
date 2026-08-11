# MGP-18: Mento V2 Deprecation

## TL;DR

With Mento V3 live, we are winding down Mento V2. This proposal reduces the trading limits on the ten FX exchanges that remain on the V2 model, replacing the current time-windowed limits with a single global limit sized at the outstanding supply of each FX stable (plus a 5% buffer). This caps the reserve's exposure to FX risk going forward while guaranteeing that every existing holder can always exit back through the Broker.

Alongside this proposal (but outside of governance), the migration multisig that owns the BiPoolManager will deprecate the following V2 exchanges, which are no longer needed on the legacy system: USDm/USDC, USDm/axlUSDC, USDm/USDT, USDm/CELO, USDm/EURm, and EURm/axlEUROC.

## Overview

Mento V3 has been running successfully since [March 2026](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103), with 15+ FPMMs deployed across three chains, over $80M in volume swapped, and three Mento stables migrated to a CDP-backed model (GBPm, CHFm, JPYm).

The transition is now far enough along to start retiring V2:

- **Retired with V2**: the collateral and 1:1 stable exchanges (USDm against USDC, axlUSDC, USDT, CELO, and EURm, plus EURm/axlEUROC) are no longer needed on the legacy system and will be destroyed by the migration multisig (see below).
- **Remaining on V2**: the ten FX stables — AUDm, CADm, ZARm, COPm, BRLm, PHPm, GHSm, NGNm, KESm, and XOFm — will not be immediately migrated to the CDP model. Their V2 exchanges against USDm stay live so that holders can always redeem, and we will work with the community to transition them to the CDP model as demand grows.

This proposal handles the second group: it reconfigures the Broker's trading limits on those ten exchanges so that the supply can fully contract, letting existing holders exit back to USDm whenever they wish.

### How the new limits work

The Broker enforces trading limits per exchange and per asset, as a combination of a 5-minute window limit (L0), a 1-day window limit (L1), and a lifetime global limit (LG) on net flows. This proposal replaces that configuration on both assets of each remaining exchange with a **global-only limit**:

- **FX asset**: the token's current total supply × 1.05.
- **USDm**: the USD equivalent of that supply at the current oracle rate × 1.05.

Sizing the limit at the outstanding supply guarantees the exit path: the entire supply can be redeemed back to USDm through the Broker. Any lower value would strand the difference. At the same time, because the global limit bounds lifetime net flow symmetrically, net new minting is capped at the same 1.05x figure — the supply can at most roughly double from the snapshot at proposal time, compared to the far larger headroom under the current limits.

Each limit is **reset before being set**: the Broker preserves the accumulated net flow when a global limit stays configured, so the first transaction clears the counter and the second applies the new limit from a clean slate.

The 5% buffer exists because the limit values are frozen into the proposal when it is created, while supply keeps moving during the voting and timelock period. The buffer absorbs moderate drift in that window, at the cost of adding the same 5% to the minting headroom.

## Transaction Details

All governance transactions call `configureTradingLimit(bytes32 exchangeId, address token, Config config)` on the Broker proxy ([`0x777A8255cA72412f0d706dc03C9D1987306B4CaD`](https://celoscan.io/address/0x777A8255cA72412f0d706dc03C9D1987306B4CaD)).

The proposal contains **40 transactions** — 4 per exchange, repeated for each of the 10 exchanges:

| TX#    | Target       | Function                | Parameters                                                  |
| ------ | ------------ | ----------------------- | ----------------------------------------------------------- |
| 4i + 0 | Broker Proxy | `configureTradingLimit` | exchangeId, FX token, empty config (reset net flow)         |
| 4i + 1 | Broker Proxy | `configureTradingLimit` | exchangeId, FX token, global-only limit = supply × 1.05     |
| 4i + 2 | Broker Proxy | `configureTradingLimit` | exchangeId, USDm, empty config (reset net flow)             |
| 4i + 3 | Broker Proxy | `configureTradingLimit` | exchangeId, USDm, global-only limit = USD equivalent × 1.05 |

The affected exchanges:

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

The exact limit values are computed from on-chain state (token total supplies and oracle rates) when the proposal is created, by `script/migration/MGP18.sol` in the [deployments repository](https://github.com/mento-protocol/deployments-v2), and can be independently reproduced by re-running the script in dry-run mode.

### Accompanying migration multisig operation

Separately from this proposal, the migration multisig ([`0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458`](https://celoscan.io/address/0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458)), which owns the BiPoolManager ([`0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901`](https://celoscan.io/address/0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901)), will deprecate the six V2 exchanges mentioned above by calling `destroyExchange` for:

- USDm/USDC
- USDm/axlUSDC
- USDm/USDT
- USDm/CELO
- USDm/EURm
- EURm/axlEUROC

Swaps for these assets are served by Mento V3 and the broader Celo DEX ecosystem; only the legacy V2 routes are removed.

## Security Considerations

- The governance transactions only touch trading-limit configuration on the Broker for existing, live exchanges. No ownership changes, no implementation upgrades, and no funds are involved.
- Reducing limits is conservative: it restricts how much the FX stables' supply can grow and thereby bounds the reserve's FX exposure; it cannot enable any new minting capacity.
- The exchange deprecations are performed by the same migration multisig that has owned the BiPoolManager since the V3 rollout began ([MGP-14](https://forum.mento.org/t/mgp-14-mento-v3-deployment-phase-1/103)). Ownership of the BiPoolManager as well as other V2 contracts will be transferred back to Mento Governance in a future MGP.
