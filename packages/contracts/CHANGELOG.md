# Changelog

All notable changes to `@mento-protocol/contracts` are documented here.
Auto-generated from `mento-deployments-v2` by `scripts/gen-contracts-package.ts`.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
