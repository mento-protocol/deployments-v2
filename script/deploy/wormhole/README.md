# Wormhole NTT Bridge — Treb-Native Approach

This document explains how the Wormhole Native Token Transfer (NTT) bridge is deployed and managed for Mento stablecoins using treb-native Solidity scripts.

## Overview

Wormhole NTT enables cross-chain token transfers using two modes:

- **Burning**: Tokens are burned on the source chain and minted on the destination. Used when both chains can mint/burn (e.g., USDm on all chains, GBPm on spoke chains).
- **Locking (hub)**: Tokens are locked on the source chain and minted on the destination. Used when the source chain holds the canonical supply (e.g., GBPm on Celo).

Each bridge consists of two contracts per chain:
- **NTT Manager** — handles peer registration, rate limits, and token locking/burning
- **Wormhole Transceiver** — handles cross-chain message transport via Wormhole

## Architecture

```
Solidity config library          Treb-native scripts
┌──────────────────────────┐    ┌────────────────────────────────┐
│  config/wormhole/        │    │  deploy/wormhole/              │
│    NTTConfig.sol         │───▶│    DeployNTT.s.sol             │
│    (topology, limits,    │    │    ConfigureNTT.s.sol          │
│     modes per token)     │    │    NttDeployHelper.sol         │
└──────────────────────────┘    └────────────────────────────────┘
                                ┌────────────────────────────────┐
                                │  actions/wormhole/             │
                                │    UpdateRateLimits.s.sol      │
                                │    UpgradeNttManager.s.sol     │
                                │    UpgradeWormholeTransceiver… │
                                │    TransferOwnership.s.sol     │
                                │    PauseNTT.s.sol              │
                                └────────────────────────────────┘
```

All configuration is defined in `NTTConfig.sol` as typed Solidity structs — no JSON files, no runtime file I/O. Config is compile-time checked and reviewable in PRs.

## Configuration

Token topology is defined in `script/config/wormhole/NTTConfig.sol`:

- `getUSDmConfig()` — returns the full bridge topology for USDm
- `getGBPmConfig()` — returns the full bridge topology for GBPm

Each config includes chain names, EVM/Wormhole chain IDs, token addressbook labels, burn/lock modes, and rate limits. Token and owner addresses are **not hardcoded** — they are addressbook labels resolved at runtime via `lookup()`.

### Token Modes

| Token | Celo | Monad | Notes |
|-------|------|-------|-------|
| USDm  | Burning | Burning | Native stablecoin, can be minted on all chains |
| GBPm  | Locking (hub) | Burning (spoke) | Canonical supply on Celo, spokes burn/mint |

## Deployment (New Token)

### Step 1: Deploy NTT contracts

```bash
treb run DeployNTT -e token=USDm --network celo --debug
treb run DeployNTT -e token=USDm --network monad --debug
```

`DeployNTT` deploys an `NttDeployHelper` via CREATE3 that bootstraps both NttManager and WormholeTransceiver ERC1967 proxies in its constructor. This workaround is needed because NTT contracts validate `msg.sender == deployer` during `initialize()`, and CREATE3 uses intermediate contracts that break this check.

### Step 2: Configure the bridge

```bash
treb run ConfigureNTT -e token=USDm --network celo --debug
treb run ConfigureNTT -e token=USDm --network monad --debug
```

`ConfigureNTT` performs all post-deployment setup:
1. Registers peer NTT Managers and Transceivers (cross-chain)
2. Sets outbound and inbound rate limits
3. Grants minter/burner permissions (if burning mode)
4. Transfers ownership and pauser capability to the configured owner

All operations are **idempotent** — re-running the script is safe and only updates values that differ from on-chain state.

> **Important**: `setWormholePeer` on the Transceiver is irreversible. Once set for a given Wormhole chain ID, it cannot be changed.

## Governance Actions

All action scripts live in `script/actions/wormhole/` and use the `token` env var to select the token config.

### Update Rate Limits

```bash
treb run UpdateRateLimits -e token=USDm --network celo --debug
```

Reads limits from `NTTConfig` and updates on-chain values if they differ. Idempotent.

### Add a New Spoke Chain

1. Add the new chain to `NTTConfig.sol` with the correct EVM/Wormhole chain IDs, token label, mode, and rate limits
2. Deploy the SpokeToken on the new chain
3. Run `DeployNTT` on the new chain
4. Run `ConfigureNTT` on **each** network (including the new chain and all existing chains) to register peers

```bash
# Deploy NTT contracts on the new spoke
treb run DeployNTT -e token=USDm --network <new-chain> --debug

# Configure peers on every chain (new + existing)
treb run ConfigureNTT -e token=USDm --network <new-chain> --debug
treb run ConfigureNTT -e token=USDm --network celo --debug
treb run ConfigureNTT -e token=USDm --network monad --debug
```

On existing chains where ownership has been transferred to a multisig, the `ConfigureNTT` step must go through a governance proposal.

### Upgrade Contracts

```bash
# Upgrade NttManager implementation
treb run UpgradeNttManager -e token=USDm -e NTT_VERSION=v2 --network celo --debug

# Upgrade WormholeTransceiver implementation
treb run UpgradeWormholeTransceiver -e token=USDm -e NTT_VERSION=v2 --network celo --debug
```

Deploys a new implementation via CREATE3 with a versioned label, then calls `upgrade()` on the proxy. New implementations must use identical constructor args (immutables) — `_checkImmutables()` validates this during upgrade.

### Transfer Ownership

```bash
treb run TransferOwnership -e token=USDm -e NEW_OWNER_LABEL=NewMultisig --network celo --debug
```

Transfers NttManager ownership (cascades to transceivers) and pauser capability (must be transferred separately on each contract).

### Pause/Unpause Bridge

```bash
# Pause
treb run PauseNTT -e token=USDm -e PAUSE=true --network celo --debug

# Unpause (requires owner, not just pauser)
treb run PauseNTT -e token=USDm -e PAUSE=false --network celo --debug
```

## Adding a New Token

1. Add `get<Token>Config()` to `NTTConfig.sol` with the full bridge topology
2. Ensure token and owner labels exist in `.treb/addressbook.json`
3. Run `DeployNTT` on each chain
4. Run `ConfigureNTT` on each chain

## Troubleshooting

### "Current chain not found in NTT config"
The script's `--network` flag doesn't match any `evmChainId` in the token's config. Check that the RPC URL points to the correct chain.

### "Transceiver peer address mismatch" after adding a spoke
`setWormholePeer` is irreversible. If set to the wrong address, you need to deploy a new Transceiver.

### Rate limit verification fails
Rate limits are stored on-chain as TrimmedAmounts (8 decimal precision for 18-decimal tokens). The scripts handle this conversion automatically.

### Ownership already transferred
If NTT contract ownership has been transferred to a multisig, further changes must go through governance action scripts with the appropriate sender profile.
