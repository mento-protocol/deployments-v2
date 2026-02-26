# Wormhole NTT Bridge Setup

This document explains how the Wormhole Native Token Transfer (NTT) bridge is configured for Mento stablecoins using the `SetupNTTBridge` script.

## Overview

Wormhole NTT enables cross-chain token transfers using two modes:

- **Locking (hub)**: Tokens are locked on the source chain and minted on the destination. Used when the source chain holds the canonical supply (e.g., GBPm on Celo).
- **Burning (spoke)**: Tokens are burned on the source chain and minted on the destination. Used for chains that mint/burn via the NTT Manager (e.g., all chains for USDm, or spoke chains for GBPm).

Each bridge consists of two contracts per chain:
- **NTT Manager** — handles peer registration, rate limits, and token locking/burning
- **Wormhole Transceiver** — handles cross-chain message transport via Wormhole

## Architecture

```
Per-token config contract          Generic setup script
┌──────────────────────┐          ┌─────────────────────┐
│  NTTConfig_USDm.sol  │──get()──>│  SetupNTTBridge.s.sol│
│  NTTConfig_GBPm.sol  │          │  (runs on any chain) │
└──────────────────────┘          └─────────────────────┘
```

Each config contract describes the **full bridge topology** for one token — all chains, their addresses, modes, and rate limits. The setup script reads the config, finds the current chain, and configures it idempotently.

## Config Structure

Configs live in `script/config/NTTConfig_<Token>.sol`. Each config returns an `NTTTokenConfig`:

```
NTTTokenConfig
├── tokenName: "USDm"
├── tokenDecimals: 18
├── rateLimitDuration: 86400 (24h, set during NTT CLI deployment)
├── ownerLabel: "MigrationMultisig" (resolved from addressbook)
└── chains[]
    ├── [0] Celo
    │   ├── chainId: 42220, wormholeChainId: 14
    │   ├── nttManager, transceiver, token (addresses)
    │   ├── isBurning: true/false
    │   ├── outboundLimit: 100_000e18
    │   └── inboundLimits: [0, 100_000e18]  (from self=ignored, from Monad)
    └── [1] Monad
        ├── chainId: 143, wormholeChainId: 48
        ├── nttManager, transceiver, token (addresses)
        ├── isBurning: true
        ├── outboundLimit: 100_000e18
        └── inboundLimits: [100_000e18, 0]  (from Celo, from self=ignored)
```

The `inboundLimits` array is parallel to the `chains` array. `inboundLimits[i]` is the inbound rate limit for traffic arriving from `chains[i]`. The entry at the chain's own index is ignored (set to 0).

## Token Modes

| Token | Celo | Monad | Notes |
|-------|------|-------|-------|
| USDm  | Burning | Burning | Native stablecoin, can be minted on all chains |
| GBPm  | Locking (hub) | Burning (spoke) | Canonical supply on Celo, spokes burn/mint |

## One-Time Setup (New Token)

### Step 1: Deploy NTT contracts via Wormhole NTT CLI

Deploy the NTT Manager and Wormhole Transceiver on each chain using the [Wormhole NTT CLI](https://wormhole.com/docs/build/contract-integrations/native-token-transfers/deployment/deploy-to-evm/). This is done outside of treb.

Key deployment parameters:
- `rateLimitDuration`: Must match the config (default: 86400 = 24 hours)
- Mode: `burning` or `locking` per chain

### Step 2: Create the config contract

Create `script/config/NTTConfig_<Token>.sol`:
1. Copy an existing config as a template
2. Fill in the deployed NTT Manager and Transceiver addresses
3. Set the token addresses (from addressbook or known addresses)
4. Configure rate limits and bridge mode per chain
5. Import the new config in `script/config/NTTConfigLib.sol`

### Step 3: Run the setup script on each chain

```bash
# On Celo
NTT_CONFIG_CONTRACT=NTTConfig_<Token> \
  treb run SetupNTTBridge --network celo --debug

# On Monad
NTT_CONFIG_CONTRACT=NTTConfig_<Token> \
  treb run SetupNTTBridge --network monad --debug
```

The script will:
1. Register all peer NTT Managers and Transceivers
2. Set outbound and inbound rate limits
3. Grant minter/burner permissions (if burning mode)
4. Transfer ownership and pauser capability to the configured owner (e.g., MigrationMultisig)

### Step 4: Verify

The script automatically verifies all configuration after setup. Check the console output for any verification failures.

## Adding a New Spoke (New Chain for Existing Tokens)

When adding a new chain (e.g., Polygon) to all existing tokens:

### For each token config:

1. **Deploy NTT contracts** on the new chain via the Wormhole NTT CLI
2. **Update the config contract**:
   - Add a new entry to the `chains` array
   - Extend all existing chains' `inboundLimits` arrays by one element (the inbound limit from the new chain)
   - Set the new chain's `inboundLimits` with entries for all existing chains

Example: Adding Polygon to a 2-chain (Celo, Monad) config:
```solidity
// Before: chains = [Celo, Monad]
// Celo inboundLimits = [0, 100_000e18]
// Monad inboundLimits = [100_000e18, 0]

// After: chains = [Celo, Monad, Polygon]
// Celo inboundLimits = [0, 100_000e18, 50_000e18]       // added: from Polygon
// Monad inboundLimits = [100_000e18, 0, 50_000e18]      // added: from Polygon
// Polygon inboundLimits = [50_000e18, 50_000e18, 0]     // new chain
```

3. **Run the script on the new chain** (full setup):
```bash
NTT_CONFIG_CONTRACT=NTTConfig_<Token> \
  treb run SetupNTTBridge --network polygon --debug
```

4. **Re-run the script on each existing chain** (only adds the new peer):
```bash
NTT_CONFIG_CONTRACT=NTTConfig_<Token> \
  treb run SetupNTTBridge --network celo --debug

NTT_CONFIG_CONTRACT=NTTConfig_<Token> \
  treb run SetupNTTBridge --network monad --debug
```

The script is idempotent — on existing chains it will skip already-configured peers and only add the new one.

> **Important**: `setWormholePeer` on the Transceiver is irreversible. Once set for a given wormhole chain ID, it cannot be changed. Double-check transceiver addresses before running.

## Updating Rate Limits

To update rate limits for an existing bridge:

1. Update the limits in the config contract
2. Re-run the script on the affected chain(s)

The script will detect that peers are already configured and only update limits if they differ from the on-chain values.

> **Note**: Ownership must not have been transferred yet, or the deployer must be the current owner. If ownership has been transferred to a multisig, rate limit updates must go through the multisig.

## Troubleshooting

### "Current chain not found in NTT config"
The script's `--network` flag doesn't match any `chainId` in the config. Check that the RPC URL points to the correct chain.

### "Transceiver peer address mismatch" after adding a spoke
`setWormholePeer` is irreversible. If set to the wrong address, you need to deploy a new Transceiver.

### Rate limit verification fails
Rate limits are stored as [TrimmedAmounts](https://github.com/wormhole-foundation/native-token-transfers/blob/main/evm/src/libraries/TrimmedAmount.sol) (8 decimal precision for 18-decimal tokens). The `_untrim` helper decodes these back to full precision. Ensure your config limits are specified in full 18-decimal precision (e.g., `100_000e18`).

### Ownership already transferred
If the NTT Manager or Transceiver ownership has already been transferred to a multisig, the deployer cannot make further changes. Subsequent configuration changes must go through the multisig.
