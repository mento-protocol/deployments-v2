# Changelog

All notable changes to `@mento-protocol/contracts` are documented here.
Auto-generated from `mento-deployments-v2` by `scripts/gen-contracts-package.ts`.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.9.0] - 2026-07-17

### Added

#### Polygon mainnet (chain 137) — new chain

Mento v3 is deployed on Polygon mainnet, adding 43 addresses under the
`mainnet` namespace. This is the headline of the release: chain 137 was
absent from the package entirely before now. It backs the EUROP/EURm FPMM
pool, with EURm and USDm bridged in over Wormhole NTT.

Tokens and collateral: `EURmSpoke`, `USDmSpoke`, `EUROP`, `USDC`.

Core: `ReserveV2` (+ `ReserveV2v300`), `Routerv300`, `Routerv301`,
`FPMMFactory` (+ `FPMMFactoryv300`), `FPMMv300`, `FactoryRegistry`
(+ `FactoryRegistryv300`), `OpenLiquidityStrategy`
(+ `OpenLiquidityStrategyv301`), `ReserveLiquidityStrategy`
(+ `ReserveLiquidityStrategyv301`), `StableTokenSpokev300`,
`StableTokenV3v300`, `ProxyAdmin`, `AddressSortedLinkedListWithMedian`.

Oracles and breakers: `SortedOracles` (+ `SortedOraclesv265`),
`OracleAdapter` (+ `OracleAdapterCollateral`, `OracleAdapterv300`),
`ChainlinkRelayerFactory` (+ `ChainlinkRelayerFactoryv265`),
`ChainlinkRelayerV1EURUSD`, `ChainlinkRelayerV1USDCUSD`,
`BreakerBoxv265`, `MedianDeltaBreakerv265`, `ValueDeltaBreakerv265`,
`MarketHoursBreakerv300`, `MarketHoursBreakerToggleablev300`.

Bridge: `NttDeployHelperEURm`, `NttDeployHelperUSDm`, `TransceiverStructs`,
`WormholeCoreBridge`.

Governance and fees: `MigrationMultisig`, `ProtocolFeeRecipient`,
`FeeSetter`, `ReserveSafe`.

#### New typed exports

- `Routerv301` — Polygon mainnet.
- `StableTokenSpokev300` — Polygon mainnet (137), Monad mainnet (143),
  Monad testnet (10143), Polygon Amoy (80002), Base Sepolia (84532).
- `ChainlinkRelayerV1relayedCELOBRL`, `ChainlinkRelayerV1relayedCELOEUR` —
  Celo mainnet.

#### Backfill of previously-unpublished deployments

The entries below are **not new on-chain**. They were deployed before this
release but never reached the package, because `contracts:update` is run
per-namespace and only for the namespaces a given PR happens to touch — so
namespaces nobody regenerates drift silently. Regenerating `mainnet` and
`testnet-v2-rc5` here swept them in. Tracked for a CI guard so this stops
recurring.

- **Celo mainnet (42220)** — 5 `ChainlinkRelayerV1` addresses, unpublished
  since 0.8.1 (2026-05-20): `ChainlinkRelayerV1CELOUSD`,
  `ChainlinkRelayerV1EUROCEUR`, `ChainlinkRelayerV1USDCUSD`,
  `ChainlinkRelayerV1relayedCELOBRL`, `ChainlinkRelayerV1relayedCELOEUR`.
- **Monad mainnet (143)** — 2 new addresses (`ChainlinkRelayerFactoryv265`,
  `SortedOraclesv265`), plus `BreakerBoxv265`, `MedianDeltaBreakerv265`,
  `StableTokenSpokev300` and `ValueDeltaBreakerv265` newly exposed under
  versioned keys (same addresses as the existing unversioned keys).
- **Polygon Amoy (80002)** — 41 addresses, the full v3 testnet set. Only
  `MockERC20EUROP` is new in this release; the other 40 predate it.
- **Base Sepolia (84532)** — 36 addresses, the full v3 testnet set, none
  previously published.
- **Monad testnet (10143)** — `StableTokenSpokev300`, a versioned alias of
  the existing `StableTokenSpoke` address.

See `contracts.json` for the complete per-chain address set.

### Notes

- **Nothing was removed and no address was re-pointed.** Every key present
  in 0.8.1 keeps its address. The `minor` bump reflects Polygon mainnet
  arriving as a new chain, not a breaking change — upgrading from 0.8.1
  should be a drop-in.

## [0.8.1] - 2026-05-20

### Fixed

- `StabilityPool.instances.<Token>[chainId]` now resolves to the
  TransparentUpgradeableProxy address (what `AddressesRegistry.stabilityPool()`
  returns on-chain), not the implementation singleton it
  `delegatecall`s into. Affects Celo mainnet (42220) and testnet-v2-rc5
  (11142220) for GBPm, CHFm, JPYm. Same shape as `SystemParams.instances`
  and `FXPriceFeed.instances`. The 0.8.0 CHANGELOG note "v300 deploy
  preferred over the older unversioned address" describes the previous (wrong)
  precedence — it should have read "the unversioned proxy is preferred over
  the v300 implementation singleton." Underlying generator config:
  `StabilityPool` group flipped from `primary`/`legacy` to `proxy`/`impl`.
- Removed orphan chain-level `StabilityPool` key (no token suffix) from Celo
  mainnet and testnet-v2-rc5 `contracts.json` — a leftover from an earlier
  generator run before the per-token split that was already being dropped
  from typed exports.
- All address entries remain in `contracts.json` under their original keys
  (`StabilityPool<Token>` proxy + `StabilityPoolv300<Token>` impl).

## [0.8.0] - 2026-04-29

This entry is hand-written — `diffContracts` only catches address/type/decimal changes in `contracts.json`, not typed-export-shape refactors like the one below, so the auto-changelog skipped it. Tracked as a follow-up to extend the diff to detect export-set changes.

### Added

- `instances` map on collapsed typed exports — `<Base>.instances.<Token>[chainId]` (or `<Base>.instances.<Pair>[chainId]` for ChainlinkRelayerV1) replaces the per-token / per-pair named exports. Bases that gained `instances`: `ActivePool`, `AddressesRegistry`, `BorrowerOperations`, `CollateralRegistry`, `CollSurplusPool`, `DefaultPool`, `FixedAssetReader`, `FXPriceFeed`, `GasPool`, `HintHelpers`, `MetadataNFT`, `MultiTroveGetter`, `NttDeployHelper`, `SortedTroves`, `SSTORE2DataPointer`, `StabilityPool`, `SystemParams`, `TroveManager`, `TroveNFT`. The `ChainlinkRelayerV1.instances` map (which already existed) is now produced by the same generic mechanism.
- `CHANGELOG.md` is now included in the published npm tarball (`files` entry; PR #64 added the file but missed wiring it into the generator's hardcoded files list).

### Removed (breaking)

- Per-token typed exports collapsed into the `<Base>.instances.<Token>` shape above. Names that no longer exist as standalone exports (use `<Base>.instances.<Token>` instead):
  - `ActivePoolv300CHFm/GBPm/JPYm`, `AddressesRegistryv300CHFm/GBPm/JPYm`, `BorrowerOperationsv300CHFm/GBPm/JPYm`, `CollateralRegistryv300CHFm/GBPm/JPYm`, `CollSurplusPoolv300CHFm/GBPm/JPYm`, `DefaultPoolv300CHFm/GBPm/JPYm`, `GasPoolv300CHFm/GBPm/JPYm`, `HintHelpersv300CHFm/GBPm/JPYm`, `MultiTroveGetterv300CHFm/GBPm/JPYm`, `SortedTrovesv300CHFm/GBPm/JPYm`, `TroveManagerv300CHFm/GBPm/JPYm`, `TroveNFTv300CHFm/GBPm/JPYm`, `MetadataNFTv300CHFm/GBPm/JPYm`, `FixedAssetReaderv300CHFm/GBPm/JPYm`, `SSTORE2DataPointerv300CHFm/GBPm/JPYm`.
  - `FXPriceFeedProxyCHFm/GBPm/JPYm`, `FXPriceFeedv300CHFm/GBPm/JPYm` → `FXPriceFeed.instances.<Token>` (proxy address).
  - `SystemParamsProxyCHFm/GBPm/JPYm`, `SystemParamsv300CHFm/GBPm/JPYm` → `SystemParams.instances.<Token>` (proxy address).
  - `StabilityPoolv300CHFm/GBPm/JPYm`, `StabilityPoolCHFm/GBPm/JPYm` → `StabilityPool.instances.<Token>` (v300 deploy preferred over the older unversioned address).
  - `NttDeployHelperUSDm/EURm/GBPm/CHFm/JPYm` → `NttDeployHelper.instances.<Token>`.
- All address entries are still in `contracts.json` under their original keys — registry consumers are unaffected.

### Changed

- Generator `INSTANCE_GROUPS` config: each pattern carries an explicit `kind: "proxy" | "primary" | "impl" | "legacy"`; precedence is now order-independent (was previously a fragile array-iteration-order invariant).
- `TOKEN` regex narrowed from `[A-Z]{2,5}m` to an explicit 15-token allowlist — silently absorbing future contracts named `EVILm` or similar is no longer possible.
- `ChainlinkRelayerV1` pattern narrowed from `(.+)` to `([A-Z]+)` so a hypothetical `ChainlinkRelayerV1Factory` can't be captured as a "pair".
- ABI mismatch in collapse now `throw`s (was `console.error` + silent skip), so CI fails loud instead of shipping a half-collapsed package.
- 160 → 97 typed exports, 157 → 94 ABI files in the published tarball.

## [0.7.0] - 2026-04-29

This entry is summarized — earlier versions were published before this changelog was wired up. From 0.8.0 onwards, entries are auto-populated from the regen diff.

### Added

- `CHFmSpoke`, `JPYmSpoke` typed exports (chains 143, 10143) — Monad spoke ABIs for CHFm/JPYm hub-and-spoke deployments.
- `NttDeployHelperCHFm`, `NttDeployHelperJPYm` typed exports.
- Per-token CDP infrastructure exports (`ActivePoolv300CHFm`, `BorrowerOperationsv300JPYm`, `TroveManagerv300GBPm`, `TroveNFTv300CHFm`, `SystemParamsv300CHFm`, `StabilityPoolv300CHFm`, etc.) for chains 42220 and 11142220 — covers the CHF/JPY CDP migration in mento-deployments-v2#62.
- `FXPriceFeedv300CHFm/GBPm/JPYm`, `FXPriceFeedProxyCHFm/GBPm/JPYm`, `FixedAssetReaderv300*`, `MetadataNFTv300*`, `SSTORE2DataPointerv300*` typed exports.
- `TransceiverStructs` typed export.

### Changed

- `CHFm` and `JPYm` ABIs updated to the V3 NTT-style implementation (was inadvertently V2 in 0.6.0; matches the deployed proxy implementation).
- `ProxyAdmin` ABI updated to the OpenZeppelin v5 shape (`UPGRADE_INTERFACE_VERSION` added; `changeProxyAdmin`/`getProxyAdmin`/`getProxyImplementation`/`upgrade` removed) — reflects what's compiled in `lib/openzeppelin-contracts`.
- New deployment addresses across `mainnet`, `testnet-v2-rc5`, and `monad-mainnet` namespaces from PRs #58 (EURm Monad mainnet), #61 (CHF/JPY deployment), and #62 (CHF/JPY CDP migration).
