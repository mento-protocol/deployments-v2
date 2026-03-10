# @mento-protocol/contracts

Typed contract ABIs and deployment addresses for the Mento protocol, auto-generated from `mento-deployments-v2`.

## Install

```bash
npm install @mento-protocol/contracts
```

## Usage

### Import a contract (ABI + address)

```typescript
import { FPMM, Broker, GBPm } from '@mento-protocol/contracts';

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

// GBPm is deployed on multiple chains — pick the right one at runtime
const gbpm = new Contract(GBPm.address[chainId], GBPm.abi, signer);
```

Each named export is `{ abi: [...] as const, address: Partial<Record<number, `0x${string}`>> }`. The `abi` is a fully typed const tuple (enabling viem type inference); `address` accepts any numeric chain ID so `client.chain.id` works without casting.

### Import the address registry

`contracts.json` is structured as `{ [chainId]: { [namespace]: { [contractName]: { address, type } } } }`.

It is primarily useful for internal tooling that needs to iterate over all contracts (e.g., dashboards, monitoring). For app code that just needs one contract, prefer the typed named exports above.

```typescript
import contracts from '@mento-protocol/contracts/contracts.json';

// ── Look up a single contract ──────────────────────────────────────────────

const sepolia = contracts['11142220']['testnet-v2-rc5'];
const fpmmAddress = sepolia.FPMM.address;   // string
const fpmmType    = sepolia.FPMM.type;      // "pool"

// ── Collect all contracts for a given chain ────────────────────────────────
// Flatten across all namespaces (last write wins on name collisions).

const chainId = '11142220';
const allForChain = Object.values(contracts[chainId] ?? {})
  .flatMap((ns) => Object.entries(ns))
  .map(([name, entry]) => ({ name, ...entry }));

// ── Collect all token contracts across all chains ──────────────────────────

const tokens = Object.entries(contracts).flatMap(([chain, namespaces]) =>
  Object.values(namespaces)
    .flatMap((ns) => Object.entries(ns))
    .filter(([, entry]) => entry.type === 'token')
    .map(([name, entry]) => ({ chain, name, ...entry })),
);

// ── Look up a contract across all namespaces on a chain ────────────────────
// Useful when you don't know which namespace a contract lives in.

function findContract(chainId: string, contractName: string) {
  const namespaces = contracts[chainId] ?? {};
  for (const ns of Object.values(namespaces)) {
    if (ns[contractName]) return ns[contractName];
  }
  return null;
}
```

#### Contract types

| `type`       | Description                                     |
|--------------|-------------------------------------------------|
| `"token"`    | ERC-20 stablecoins and collateral tokens        |
| `"pool"`     | FPMM liquidity pools                            |
| `"contract"` | All other protocol contracts (oracles, CDP, …) |

### Import a raw ABI JSON (alternative)

```typescript
import abi from '@mento-protocol/contracts/abis/FPMM.json';
```

## Available namespaces

| Chain ID   | Network               | Namespace          |
|------------|-----------------------|--------------------|
| `42220`    | Celo Mainnet          | `mainnet`          |
| `11142220` | Celo Sepolia          | `testnet-v2-rc5`   |
| `143`      | Monad Testnet         | `mainnet`          |

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
npm run contracts:update -- --namespace=testnet-v2-rc5
```

The script merges results into a single `contracts.json` and regenerates `abis/` and `src/`. It is safe to run multiple times — if nothing changed it prints "No changes detected" and exits without modifying any files.

If `out/` is missing, the script will prompt you to run `forge build` first (needed to read ABIs from compiled Foundry artifacts).

### Step 2 — Commit the generated files

```bash
git add packages/contracts/
git commit -m "chore: update contracts package for <namespace>"
```

### Step 3 — Bump the version and publish

Decide on the bump type:

| Change type | Version bump |
|---|---|
| New contract added / address changed | `patch` |
| Existing contract renamed or removed (breaking) | `minor` |
| API redesign (breaking) | `major` |

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

### Naming rules

The script derives a canonical export name from each entry in the treb registry using these rules (in priority order):

| Registry key pattern          | Export name               |
|-------------------------------|---------------------------|
| `Proxy:GBPm`                  | `GBPm`                    |
| `TransparentUpgradeableProxy:X` | `X`                     |
| `TransparentUpgradeableProxy:X:Y` | `XY`                  |
| `ChainlinkRelayerV1:vN.N.N-AUDUSD` | `ChainlinkRelayerV1AUDUSD` |
| `plain key`                   | as-is                     |

Old V2 token names (`cGBP`, `cUSD`, etc.) are mapped to their V3 equivalents (`GBPm`, `USDm`, etc.) via `scripts/contract-name-overrides.json`.

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
