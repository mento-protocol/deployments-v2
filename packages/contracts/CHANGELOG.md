# Changelog

All notable changes to `@mento-protocol/contracts` are documented here.
Auto-generated from `mento-deployments-v2` by `scripts/gen-contracts-package.ts`.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
