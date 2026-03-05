# @mento-protocol/contracts

Typed contract ABIs and deployment addresses for the Mento protocol, auto-generated from `mento-deployments-v2`.

## Install

```bash
npm install @mento-protocol/contracts
```

## Usage

### Import a contract ABI (for use with viem, ethers, etc.)

```typescript
import { FPMM, Broker, GBPm } from '@mento-protocol/contracts';

// Use FPMM.abi with viem
const fpmmContract = getContract({
  address: '0x...',
  abi: FPMM.abi,
  client,
});

// Use with ethers
const broker = new Contract(address, Broker.abi, signer);
```

Each named export is an object `{ abi: [...] as const }`. The `as const` assertion enables full TypeScript type inference with viem.

### Import the address registry

```typescript
import contracts from '@mento-protocol/contracts/contracts.json';

// contracts is structured as:
// { [chainId]: { [namespace]: { [contractName]: { address, type } } } }

const sepolia = contracts['11142220']['testnet-v2-rc5'];
const fpmmAddress = sepolia.FPMM.address;       // string
const fpmmType = sepolia.FPMM.type;             // "pool"
const gbpmAddress = sepolia.GBPm.address;       // string
const gbpmType = sepolia.GBPm.type;             // "token"
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
| `11142220` | Celo Sepolia          | `testnet-v2-rc5`   |
| `143`      | Monad Testnet         | `monad-mainnet`    |

## Generating / updating the package

The package contents are fully auto-generated. **Never edit `contracts.json`, `abis/`, or `src/` by hand.**

### Prerequisites

1. A working Foundry setup — ABIs are read from compiled artifacts in `out/`.
2. The deployment registry in `.treb/deployments.json` must be up to date.

### Run the generator

From the repo root:

```bash
# Generate / update for a single namespace (prompted interactively if omitted)
npm run contracts:update

# Or pass the namespace directly
npm run contracts:update -- --namespace=testnet-v2-rc5
npm run contracts:update -- --namespace=monad-mainnet
```

The script accumulates namespaces into a single `contracts.json`; run it once per namespace. It is safe to run multiple times — if nothing changed it prints "No changes detected".

If `out/` is missing, the script will prompt you to run `forge build` first.

### After generating

Review the diff printed by the script, then build and publish:

```bash
cd packages/contracts
npm run build          # tsc → dist/
npm version patch      # or minor / major
npm publish
```

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

Proxies always take precedence over their implementation singletons when both would resolve to the same name (the proxy address is what callers use, with the implementation's ABI).

## Structure

```
packages/contracts/
├── abis/              # Raw ABI JSON files (one per contract)
├── src/               # TypeScript modules (auto-generated, do not edit)
│   ├── FPMM.ts        # export const FPMM = { abi: [...] as const }
│   ├── GBPm.ts
│   ├── index.ts       # barrel re-exporting all contracts
│   └── ...
├── dist/              # Compiled output (not committed, produced by tsc)
├── contracts.json     # Address registry (auto-generated, do not edit)
├── package.json       # Auto-updated by the generator (exports map)
└── tsconfig.json
```
