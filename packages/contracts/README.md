# @mento-protocol/contracts

Typed contract ABIs and deployment addresses for the Mento protocol, auto-generated from `mento-deployments-v2`.

## Install

```bash
npm install @mento-protocol/contracts
```

## Usage

### Import a contract (ABI + address)

```typescript
import { FPMM, Broker, GBPm } from "@mento-protocol/contracts";

// Each export has both abi and address keyed by chainId
const CELO_SEPOLIA = 11142220;

// Use with viem
const fpmmContract = getContract({
  address: FPMM.address[CELO_SEPOLIA],
  abi: FPMM.abi,
  client,
});

// Use with ethers
const broker = new Contract(Broker.address[CELO_SEPOLIA], Broker.abi, signer);

// GBPm is deployed on multiple chains — pick the right one at runtime.
// NOTE: GBPm covers the *hub* chains (Celo mainnet and Sepolia). On the
// Monad *spoke* chains (143, 10143) use GBPmSpoke instead — the hub and
// spoke contracts have different ABIs. Same pattern for USDm / USDmSpoke
// and EURm / EURmSpoke.
const gbpm = new Contract(GBPm.address[chainId], GBPm.abi, signer);
```

Each named export is `{ abi: [...] as const, address: Partial<Record<number, `0x${string}`>> }`. The `abi` is a fully typed const tuple (enabling viem type inference); `address` accepts any numeric chain ID so `client.chain.id` works without casting.

### Per-token / per-pair contracts use `instances`

Some contracts get deployed once per stable token (e.g. `ActivePool` on Celo Mainnet has separate `CHFm`, `GBPm`, `JPYm` instances) or once per rate feed pair (`ChainlinkRelayerV1` has `EURUSD`, `JPYUSD`, etc.). All instances share the same ABI, so they're folded into a single typed export with an `instances` map keyed by the discriminator:

```typescript
import {
  ActivePool,
  ChainlinkRelayerV1,
  NttDeployHelper,
} from "@mento-protocol/contracts";

// Per-token CDP contracts
const activePool = new Contract(
  ActivePool.instances.CHFm[42220],
  ActivePool.abi,
  signer,
);

// Per-pair rate-feed relayers
const relayer = new Contract(
  ChainlinkRelayerV1.instances.EURUSD[chainId],
  ChainlinkRelayerV1.abi,
  signer,
);

// Per-token NTT helpers
const helper = new Contract(
  NttDeployHelper.instances.USDm[143],
  NttDeployHelper.abi,
  signer,
);
```

Exports that use `instances`: `ChainlinkRelayerV1` (per pair), `NttDeployHelper`, and the v3.0.0 CDP family — `ActivePool`, `AddressesRegistry`, `BorrowerOperations`, `CollateralRegistry`, `CollSurplusPool`, `DefaultPool`, `FixedAssetReader`, `FXPriceFeed`, `GasPool`, `HintHelpers`, `MetadataNFT`, `MultiTroveGetter`, `SortedTroves`, `SSTORE2DataPointer`, `StabilityPool`, `SystemParams`, `TroveManager`, `TroveNFT` (all per token: `CHFm` / `GBPm` / `JPYm`).

For `FXPriceFeed` and `SystemParams`, `instances.<token>` is the **proxy** address (what you call). The implementation address remains in `contracts.json` as `<base>v300<token>` if you need it for tooling.

### Import the address registry

`contracts.json` is structured as `{ [chainId]: { [namespace]: { [contractName]: { address, type } } } }`.

It is primarily useful for internal tooling that needs to iterate over all contracts (e.g., dashboards, monitoring). For app code that just needs one contract, prefer the typed named exports above.

```typescript
import contracts from "@mento-protocol/contracts/contracts.json";

// ── Look up a single contract ──────────────────────────────────────────────

const sepolia = contracts["11142220"]["testnet-v2-rc5"];
const fpmmAddress = sepolia.FPMM.address; // string
const fpmmType = sepolia.FPMM.type; // "pool"

// ── Collect all contracts for a given chain ────────────────────────────────
// A chain can appear under multiple namespaces (e.g. chain 143 has both
// `mainnet` and `monad-mainnet` entries). The flatMap below returns the
// full cross-product, so the same contract name may appear more than once
// if it's present in multiple namespaces with different addresses — dedupe
// by (name, address) if that matters for your use case.

const chainId = "11142220";
const allForChain = Object.values(contracts[chainId] ?? {})
  .flatMap((ns) => Object.entries(ns))
  .map(([name, entry]) => ({ name, ...entry }));

// ── Collect all token contracts across all chains ──────────────────────────

const tokens = Object.entries(contracts).flatMap(([chain, namespaces]) =>
  Object.values(namespaces)
    .flatMap((ns) => Object.entries(ns))
    .filter(([, entry]) => entry.type === "token")
    .map(([name, entry]) => ({ chain, name, ...entry })),
);

// ── Look up a contract across all namespaces on a chain ────────────────────
// When a chain has multiple namespaces, this returns the FIRST match
// encountered in iteration order. That's fine for unique contracts, but for
// names that appear in more than one namespace (e.g. different deployment
// generations) you should filter on the namespace key explicitly.

function findContract(chainId: string, contractName: string) {
  const namespaces = contracts[chainId] ?? {};
  for (const ns of Object.values(namespaces)) {
    if (ns[contractName]) return ns[contractName];
  }
  return null;
}
```

#### Contract types

| `type`       | Description                                    |
| ------------ | ---------------------------------------------- |
| `"token"`    | ERC-20 stablecoins and collateral tokens       |
| `"pool"`     | FPMM liquidity pools                           |
| `"contract"` | All other protocol contracts (oracles, CDP, …) |

### Import a raw ABI JSON (alternative)

```typescript
import abi from "@mento-protocol/contracts/abis/FPMM.json";
```

## Available namespaces

| Chain ID   | Network       | Namespace(s)               |
| ---------- | ------------- | -------------------------- |
| `42220`    | Celo Mainnet  | `mainnet`                  |
| `11142220` | Celo Sepolia  | `testnet-v2-rc5`           |
| `143`      | Monad Mainnet | `mainnet`, `monad-mainnet` |
| `10143`    | Monad Testnet | `testnet-v2-rc5`           |

## Generating / updating the package

The package contents are fully auto-generated. **Never edit `contracts.json`, `abis/`, or `src/` by hand.**

### Prerequisites

1. A working Foundry setup — ABIs are read from compiled artifacts in `out/`.
2. The deployment registry in `.treb/deployments.json` must be up to date.
3. npm login with publish access to the `@mento-protocol` org (first-time only).

### Step 1 — Re-generate after new deployments

From the repo root, run the generator once per namespace that changed:

```bash
# Interactive namespace picker
npm run contracts:update

# Or pass the namespace directly
npm run contracts:update -- --namespace=mainnet
npm run contracts:update -- --namespace=monad-mainnet
npm run contracts:update -- --namespace=testnet-v2-rc5
```

The script merges results into a single `contracts.json` and regenerates `abis/` and `src/`. When the regen produces a non-empty diff, the Added/Removed/Changed entries are also appended to the `## [Unreleased]` section of `CHANGELOG.md`. It is safe to run multiple times — if nothing changed it prints "No changes detected" and exits without modifying any files.

If `out/` is missing, the script will prompt you to run `forge build` first (needed to read ABIs from compiled Foundry artifacts).

### Step 2 — Commit the generated files

```bash
git add packages/contracts/
git commit -m "chore: update contracts package for <namespace>"
```

### Step 3 — Bump the version and publish

Decide on the bump type:

| Change type                                     | Version bump |
| ----------------------------------------------- | ------------ |
| New contract added / address changed            | `patch`      |
| Existing contract renamed or removed (breaking) | `minor`      |
| API redesign (breaking)                         | `major`      |

```bash
cd packages/contracts

# Bump version in package.json and create a git tag
npm version patch   # or minor / major

# Publish to npm — prepublishOnly runs tsc automatically
npm publish --access public

# Push the version commit and tag
cd ../..
git push && git push --tags
```

`prepublishOnly` runs `tsc` automatically before every publish, so `dist/` is always built from the current `src/`. You never need to run `npm run build` manually before publishing.

The `version` lifecycle hook renames `## [Unreleased]` in `CHANGELOG.md` to `## [<new-version>] - <today>` and stages it, so the version commit always carries the matching changelog entry. If you ran `npm run contracts:update` between regen and bump, those entries are exactly what gets released.

The hook **fails the version bump** if `[Unreleased]` is empty, or if the new version heading already exists in `CHANGELOG.md`. To override either guard (e.g. for a metadata-only release), invoke the rename script directly with `--allow-empty`: `node ../../scripts/release-changelog.mjs <version> --allow-empty`.

Dedup notes for entries appended by `npm run contracts:update`:

- `### Added` and `### Removed` are deduped by full-string match on the contract identifier.
- `### Changed` is deduped by `<chainId>/<ns>/<name>` prefix — a follow-up regen that bumps the same contract again collapses to a single line keyed on the latest state, instead of leaving a stale arrow chain.

### Naming rules

The script derives a canonical export name from each entry in the treb registry using these rules (in priority order):

| Registry key pattern              | Export name                               |
| --------------------------------- | ----------------------------------------- |
| `Proxy:GBPm`                      | `GBPm`                                    |
| `TransparentUpgradeableProxy:X`   | `X`                                       |
| `TransparentUpgradeableProxy:X:Y` | `XY`                                      |
| `ChainlinkRelayerV1<Pair>`        | `ChainlinkRelayerV1` (instances.`<Pair>`) |
| `plain key`                       | as-is                                     |

Old V2 token names (`cGBP`, `cUSD`, etc.) are mapped to their V3 equivalents (`GBPm`, `USDm`, etc.) via `scripts/contract-name-overrides.json`. Multichain tokens use a hub-and-spoke deployment with different ABIs per side; the Monad-side proxies are mapped to `USDmSpoke`/`EURmSpoke`/`GBPmSpoke` so each export carries exactly the ABI that matches its address map.

All `ChainlinkRelayerV1*` per-pair deployments share the same ABI, so the generator collapses them into a single typed export (`ChainlinkRelayerV1`) with per-pair addresses under `instances`. Mock contracts (`Mock*`) are testnet-only scaffolding and don't get typed exports; their addresses remain in `contracts.json` for deployment tooling.

The generator validates every entry in `contract-name-overrides.json` against the active namespace on each run and warns about keys that no longer match any deployment — a sign the entry is stale and can be deleted.

Proxies always take precedence over their implementation singletons when both would resolve to the same name (the proxy address is what callers use, with the implementation's ABI).

## Structure

```
packages/contracts/
├── abis/              # Raw ABI JSON files (one per contract)
├── src/               # TypeScript modules (auto-generated, do not edit)
│   ├── FPMM.ts        # export const FPMM = { abi: [...] as const, address: Partial<Record<number, `0x${string}`>> }
│   ├── GBPm.ts        # address map spans all chains the token is deployed on
│   ├── index.ts       # barrel re-exporting all contracts
│   └── ...
├── dist/              # Compiled output (not committed, produced by tsc)
├── contracts.json     # Address registry (auto-generated, do not edit)
├── package.json       # Auto-updated by the generator (exports map)
└── tsconfig.json
```
