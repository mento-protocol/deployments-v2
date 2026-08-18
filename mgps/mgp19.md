<!-- markdownlint-disable MD036 MD041 -->

## TL;DR

This proposal is the on-chain companion to the forum proposal _Returning the Mento Issuance Protocol to Celo_ (§1, "Transfer of issuance governance to Celo Governance"). It transfers on-chain governance of the **issuance side** of the Mento Protocol on Celo — the 15 Mento stable assets, the direct reserve mint/burn path (Broker, BiPoolManager, Reserve), the V3 reserve issuance contracts (ReserveV2, ReserveLiquidityStrategy, CDPLiquidityStrategy), the CDP branches (GBPm, CHFm, JPYm) and the oracle layer that gates minting and burning — to **Celo Governance** (`0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972`).

Everything else stays exactly where it is: the Mento FX DEX (FPMM factory/registry, pools, router, virtual pools, OpenLiquidityStrategy, oracle adapters), the MENTO token, and Mento Governance itself remain under Mento Governance / Mento Labs.

The issuance rights are currently split between the Mento Governance timelock and the Mento Labs migration multisig, which received a number of them on a temporary basis in MGP-14 and MGP-16 for the V3 rollout. This proposal therefore has two legs that are generated from a single script:

1. **This governance proposal (26 transactions)** — everything the Mento Governance timelock holds.
2. **A migration-multisig batch (35 transactions)** — everything the migration multisig (`0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458`) still holds. Instead of first returning those rights to Mento Governance and then forwarding them, the multisig transfers them to Celo Governance directly, on approval of this proposal and after the operations described in MGP-18 are complete.

---

## Overview

Mento has grown into two distinct products. **Issuance** — the stable assets, CDPs and direct reserve elastic mint/burn — belongs to a credibly decentralised community, and Celo Governance, where the protocol originated, is its natural home. **The FX DEX** — oracle-priced, zero-slippage stablecoin FX via FPMMs — is infrastructure best served by a focused operating team, and remains with Mento Governance and Mento Labs.

The transfer covers stable-asset mint/burn parameters and upgrades, CDP parameters, reserve composition policy and every admin/owner role on the issuance contracts. Concretely, for each contract in scope the following rights move to Celo Governance:

- **Proxy admin** — the right to upgrade the implementation (Celo legacy proxies: `_transferOwnership`; OpenZeppelin `TransparentUpgradeableProxy`: ownership of the proxy's `ProxyAdmin`).
- **Contract owner** — the `Ownable` role that sets parameters and roles (`transferOwnership`).

All ownership on these contracts is single-step (`Ownable` / `OwnableUpgradeable`), so no acceptance transaction from Celo Governance is required. After execution, Celo Governance exercises these rights through regular Celo governance proposals.

### What moves to Celo Governance

| Group | Contracts | Rights moved |
| --- | --- | --- |
| Stable assets (StableTokenV2) | BRLm, XOFm, KESm, PHPm, COPm, GHSm, ZARm, CADm, AUDm, NGNm | proxy admin + owner |
| Stable assets (StableTokenV3) | USDm, EURm, GBPm, CHFm, JPYm | proxy admin + owner (incl. minter/burner/operator role management) |
| Direct reserve mint/burn (Mento V2) | Broker, BiPoolManager, Reserve | proxy admin + owner |
| Oracle layer | SortedOracles (proxy admin + owner), BreakerBox, MedianDeltaBreaker, ValueDeltaBreaker, ChainlinkRelayerFactory (owner) | see table below |
| V3 reserve issuance | ReserveV2, ReserveLiquidityStrategy, CDPLiquidityStrategy, ReserveTroveFactory | ProxyAdmin owner + owner (ReserveTroveFactory: owner) |
| CDP branches (GBPm, CHFm, JPYm) | FXPriceFeed ×3 (ProxyAdmin owner + owner), SystemParams ×3 and StabilityPool ×3 (ProxyAdmin owner — their parameters change only via upgrade) | see table below |

The remaining CDP contracts (AddressesRegistry, BorrowerOperations, TroveManager, ActivePool, DefaultPool, CollSurplusPool, GasPool, SortedTroves, TroveNFT, MetadataNFT, HintHelpers, MultiTroveGetter, CollateralRegistry, FixedAssetReader) and the V2 pricing modules are immutable or have renounced ownership; there is nothing to transfer.

### What stays with Mento Governance / Mento Labs

- **Mento FX DEX:** FPMMFactory, FactoryRegistry, all FPMM pools, Router, VirtualPoolFactory, OpenLiquidityStrategy, OracleAdapter, OracleAdapterCollateral, MarketHoursBreakerToggleable.
- **Mento DAO:** MentoGovernor, TimelockController, Locking, MENTO token, Emission, Airgrab and the ProxyAdmin that administers the governance proxies.

The script asserts before and after execution that none of these change hands.

---

### Security Considerations

**Risk Assessment**

- Ownership and upgrade rights over the issuance contracts move to Celo Governance, a well-established on-chain governance process with its own proposal, referendum and execution stages. No implementation is changed and no parameter is modified by this proposal.
- The Mento FX DEX and the Mento DAO are out of scope; the proposal script verifies that their ownership is untouched.
- Operational continuity: minter/burner roles, exchange configuration, oracle whitelists and breaker configuration are unchanged, so swaps, minting, burning and CDP operations continue exactly as before. Only the ability to change them moves.
- The two legs are not atomic (a Mento Governance proposal and a multisig batch). Between them, some contracts are already under Celo Governance while others are still with the migration multisig — the same split that exists today.

**Follow-ups (not part of this proposal)**

- The `ProxyAdmin` of the ChainlinkRelayerFactory proxy (`0xba63992987f2e4C6B458922165fEd3C5f368F09b`) is owned by a legacy Mento Labs multisig (`0x655133d8E90F8190ed5c1F0f3710F602800C0150`, 3/8). It is not a signer configured for this script and will transfer that ProxyAdmin to Celo Governance in a separate multisig transaction. The factory's contract owner is transferred by this proposal.
- The FXPriceFeeds of the CDP branches read prices through the `OracleAdapter` proxy, which is part of the FX DEX and stays with Mento Labs. Celo Governance can re-point each FXPriceFeed to any adapter it controls (`setOracleAdapter`); deploying a Celo-Governance-owned adapter for the CDP branches can be done in a follow-up.
- Sequencing with MGP-18: the migration multisig deprecates the remaining V2 exchanges through the BiPoolManager under MGP-18. The multisig batch of this proposal (which hands the BiPoolManager owner role to Celo Governance) is executed after those operations are complete.

**Safety Measures**

- The proposal was generated and simulated with `treb` from `script/migration/MGP19.sol`. The script routes every right to whichever sender currently holds it and reverts if any right is held by anyone else, then verifies (a) that Celo Governance holds every right, (b) that all out-of-scope contracts are unchanged, and (c) that Celo Governance can exercise the transferred powers (upgrade each proxy, manage minters, configure Broker/BiPoolManager/Reserve, whitelist oracles, add breakers, configure the breakers and the relayer factory).
- Transaction hashes will be shared on the forum for community verification.

---

### Transaction Details

**Step 1: Mento Governance proposal (26 transactions, executed by the timelock `0x890DB8A597940165901372Dd7DB61C9f246e2147`)**

For each of the 10 StableTokenV2 assets, the Broker and the Reserve, two calls: `_transferOwnership(0xD533…7972)` on the proxy and `transferOwnership(0xD533…7972)` on the contract. For the BiPoolManager and SortedOracles, whose contract owner is the migration multisig (MGP-14), one call: `_transferOwnership(0xD533…7972)` on the proxy.

| Contract | Address | Calls |
| --- | --- | --- |
| BRLm | 0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787 | `_transferOwnership`, `transferOwnership` |
| XOFm | 0x73F93dcc49cB8A239e2032663e9475dd5ef29A08 | `_transferOwnership`, `transferOwnership` |
| KESm | 0x456a3D042C0DbD3db53D5489e98dFb038553B0d0 | `_transferOwnership`, `transferOwnership` |
| PHPm | 0x105d4A9306D2E55a71d2Eb95B81553AE1dC20d7B | `_transferOwnership`, `transferOwnership` |
| COPm | 0x8A567e2aE79CA692Bd748aB832081C45de4041eA | `_transferOwnership`, `transferOwnership` |
| GHSm | 0xfAeA5F3404bbA20D3cc2f8C4B0A888F55a3c7313 | `_transferOwnership`, `transferOwnership` |
| ZARm | 0x4c35853A3B4e647fD266f4de678dCc8fEC410BF6 | `_transferOwnership`, `transferOwnership` |
| CADm | 0xff4Ab19391af240c311c54200a492233052B6325 | `_transferOwnership`, `transferOwnership` |
| AUDm | 0x7175504C455076F15c04A2F90a8e352281F492F9 | `_transferOwnership`, `transferOwnership` |
| NGNm | 0xE2702Bd97ee33c88c8f6f92DA3B733608aa76F71 | `_transferOwnership`, `transferOwnership` |
| Broker | 0x777A8255cA72412f0d706dc03C9D1987306B4CaD | `_transferOwnership`, `transferOwnership` |
| Reserve | 0x9380fA34Fd9e4Fd14c06305fd7B6199089eD4eb9 | `_transferOwnership`, `transferOwnership` |
| BiPoolManager | 0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901 | `_transferOwnership` |
| SortedOracles | 0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33 | `_transferOwnership` |

**Step 2: Migration multisig batch (35 transactions, executed by `0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458`)**

| Contract | Address | Calls |
| --- | --- | --- |
| USDm | 0x765DE816845861e75A25fCA122bb6898B8B1282a | `_transferOwnership`, `transferOwnership` |
| EURm | 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73 | `_transferOwnership`, `transferOwnership` |
| GBPm | 0xCCF663b1fF11028f0b19058d0f7B674004a40746 | `_transferOwnership`, `transferOwnership` |
| CHFm | 0xb55a79F398E759E43C95b979163f30eC87Ee131D | `_transferOwnership`, `transferOwnership` |
| JPYm | 0xc45eCF20f3CD864B32D9794d6f76814aE8892e20 | `_transferOwnership`, `transferOwnership` |
| BiPoolManager | 0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901 | `transferOwnership` |
| SortedOracles | 0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33 | `transferOwnership` |
| BreakerBox | 0x303ED1df62Fa067659B586EbEe8De0EcE824Ab39 | `transferOwnership` |
| MedianDeltaBreaker | 0x49349F92D2B17d491e42C8fdB02D19f072F9B5D9 | `transferOwnership` |
| ValueDeltaBreaker | 0x4DBC33B3abA78475A5AA4BC7A5B11445d387BF68 | `transferOwnership` |
| ReserveTroveFactory | 0x02859465DCC7D7F2Bee183fC7FaC78544c9519e1 | `transferOwnership` |
| ChainlinkRelayerFactory | 0x247cb6ecf21bdd2bc29d726cccc8d2f066211663 | `transferOwnership` |
| ReserveV2 | 0x4255Cf38e51516766180b33122029A88Cb853806 (ProxyAdmin 0x363b8CEf44f88cE7B41B8576FC493A3c5946951F) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| ReserveLiquidityStrategy | 0xa0fB8b16ce6AF3634fF9F3f4F40E49E1C1ae4f0B (ProxyAdmin 0x30FCd4fd891f7dE98606bF97cB8654f7bA33C4e7) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| CDPLiquidityStrategy | 0x4e78BD9565341EAbe99cDC024acB044d9BDcB985 (ProxyAdmin 0xbA6F1EED14f21bCc247C48313fd375F5614a24EE) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| FXPriceFeed GBPm | 0xBBB144A67f4403112b4C895Cc85d5EE4F90013DE (ProxyAdmin 0xD5eF27F8472ffA5A0e05e3b013f44E720422a283) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| FXPriceFeed CHFm | 0x8a94073809E9Ae55626c2FD413826bF93f755a73 (ProxyAdmin 0x12b430d8E407A79CdA01F12112ddEF8eb593AEEf) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| FXPriceFeed JPYm | 0x8409587c8BA4f6850AEE09A32B86022C3E88AD33 (ProxyAdmin 0x54E70f44bC374f0561f69695E8F4c65d49214710) | ProxyAdmin `transferOwnership`, `transferOwnership` |
| SystemParams GBPm | 0x70536e44d1D9238BA8E35Ffe63Bb388a63F0DE51 (ProxyAdmin 0x7057d1dB4CB9270742c7069F4e106440d0dC3288) | ProxyAdmin `transferOwnership` |
| SystemParams CHFm | 0xe604507642469bE4699FeBDf4A701D9A104dd173 (ProxyAdmin 0x68932b8fDd82dA5B0fCe2AcA20A82ea0e11D894A) | ProxyAdmin `transferOwnership` |
| SystemParams JPYm | 0xC7829C5D1701aB366D248ca384C4caefD87EcDF1 (ProxyAdmin 0xA28D14998f1934719B73A06A706E43F0a9A4Cb35) | ProxyAdmin `transferOwnership` |
| StabilityPool GBPm | 0x06346c0fAB682dBde9f245D2D84677592E8aaa15 (ProxyAdmin 0xC54645149c6EDE8b9d52FB8d3daB8977A843De3B) | ProxyAdmin `transferOwnership` |
| StabilityPool CHFm | 0xc415cA43aB6Ab246E64559696b8DCAcdd08A39e8 (ProxyAdmin 0x4aaFD05073Cd55D6E22B0cDADdC7679d35EDc94E) | ProxyAdmin `transferOwnership` |
| StabilityPool JPYm | 0x62A519b4D0693E976b78b195E34a548BcF1D2355 (ProxyAdmin 0xCEad352Df8eB785e90f23D1d1eEE9D593270fD3A) | ProxyAdmin `transferOwnership` |

In every call the new owner is Celo Governance, `0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972` (Celo Registry entry `Governance`).
