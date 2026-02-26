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
Per-token deployment JSON              Generic setup script
┌──────────────────────────────┐      ┌──────────────────────┐
│  config/wormhole/USDm.json   │─read─│  SetupNTTBridge.s.sol │
│  config/wormhole/GBPm.json   │      │  (runs on any chain)  │
└──────────────────────────────┘      └──────────────────────┘
```

Each JSON file describes the **full bridge topology** for one token — all chains, their deployed addresses, modes, and rate limits. The setup script reads the JSON, finds the current chain, and configures it idempotently.

The JSON extends the Wormhole NTT CLI output format with additional fields (`chainId`, `wormholeChainId`, `isBurning`, `tokenName`, `tokenDecimals`, `ownerLabel`) needed by the setup script.

## JSON Config Structure

Configs live in `script/config/wormhole/<Token>.json`:

```json
{
  "tokenName": "USDm",
  "tokenDecimals": 18,
  "ownerLabel": "MigrationMultisig",
  "chains": {
    "Celo": {
      "chainId": 42220,
      "wormholeChainId": 14,
      "manager": "0x...",
      "transceivers": { "wormhole": { "address": "0x..." } },
      "token": "0x...",
      "isBurning": true,
      "limits": {
        "inbound": { "Monad": "100000000000000000000000" },
        "outbound": "100000000000000000000000"
      }
    },
    "Monad": {
      "chainId": 143,
      "wormholeChainId": 48,
      "manager": "0x...",
      "transceivers": { "wormhole": { "address": "0x..." } },
      "token": "0x...",
      "isBurning": true,
      "limits": {
        "inbound": { "Celo": "100000000000000000000000" },
        "outbound": "100000000000000000000000"
      }
    }
  }
}
```

Key fields:
- **`manager`**, **`transceivers.wormhole.address`**: Deployed by the Wormhole NTT CLI
- **`token`**: The token address on this chain (from addressbook or known)
- **`isBurning`**: `false` = locking (hub), `true` = burning (spoke)
- **`limits.inbound.<PeerName>`**: Inbound rate limit from that peer chain (full 18-decimal precision)
- **`limits.outbound`**: Outbound rate limit (full 18-decimal precision)
- **`ownerLabel`**: Addressbook key for the final owner (e.g., `"MigrationMultisig"`)

## Token Modes

| Token | Celo | Monad | Notes |
|-------|------|-------|-------|
| USDm  | Burning | Burning | Native stablecoin, can be minted on all chains |
| GBPm  | Locking (hub) | Burning (spoke) | Canonical supply on Celo, spokes burn/mint |

## One-Time Setup (New Token)

### Step 1: Deploy NTT contracts via Wormhole NTT CLI

Deploy the NTT Manager and Wormhole Transceiver on each chain using the [Wormhole NTT CLI](https://wormhole.com/docs/build/contract-integrations/native-token-transfers/deployment/deploy-to-evm/). This is done outside of treb.

Key deployment parameters:
- `rateLimitDuration`: Must match `RATE_LIMIT_DURATION` env var (default: 86400 = 24 hours)
- Mode: `burning` or `locking` per chain

### Step 2: Create the deployment JSON

Create `script/config/wormhole/<Token>.json`:
1. Copy an existing JSON as a template (e.g., `USDm.json`)
2. Fill in the deployed NTT Manager and Transceiver addresses from CLI output
3. Set the token addresses, chain IDs, wormhole chain IDs
4. Set `isBurning` per chain (`false` for hub/locking, `true` for spoke/burning)
5. Configure rate limits

### Step 3: Run the setup script on each chain

```bash
# On Celo
WORMHOLE_DEPLOYMENT_FILE=script/config/wormhole/<Token>.json \
  treb run SetupNTTBridge --network celo --debug

# On Monad
WORMHOLE_DEPLOYMENT_FILE=script/config/wormhole/<Token>.json \
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
2. **Update the JSON config**:
   - Add a new chain entry under `.chains`
   - Add an inbound limit entry for the new chain in each existing chain's `.limits.inbound`
   - Set the new chain's `.limits.inbound` with entries for all existing chains

Example: Adding Polygon to a 2-chain (Celo, Monad) config:
```json
{
  "chains": {
    "Celo": {
      "limits": {
        "inbound": { "Monad": "100000...", "Polygon": "50000..." },
        "outbound": "100000..."
      }
    },
    "Monad": {
      "limits": {
        "inbound": { "Celo": "100000...", "Polygon": "50000..." },
        "outbound": "100000..."
      }
    },
    "Polygon": {
      "chainId": 137,
      "wormholeChainId": 5,
      "manager": "0x...",
      "transceivers": { "wormhole": { "address": "0x..." } },
      "token": "0x...",
      "isBurning": true,
      "limits": {
        "inbound": { "Celo": "50000...", "Monad": "50000..." },
        "outbound": "50000..."
      }
    }
  }
}
```

3. **Run the script on the new chain** (full setup):
```bash
WORMHOLE_DEPLOYMENT_FILE=script/config/wormhole/<Token>.json \
  treb run SetupNTTBridge --network polygon --debug
```

4. **Re-run the script on each existing chain** (only adds the new peer):
```bash
WORMHOLE_DEPLOYMENT_FILE=script/config/wormhole/<Token>.json \
  treb run SetupNTTBridge --network celo --debug

WORMHOLE_DEPLOYMENT_FILE=script/config/wormhole/<Token>.json \
  treb run SetupNTTBridge --network monad --debug
```

The script is idempotent — on existing chains it will skip already-configured peers and only add the new one.

> **Important**: `setWormholePeer` on the Transceiver is irreversible. Once set for a given wormhole chain ID, it cannot be changed. Double-check transceiver addresses before running.

## Updating Rate Limits

To update rate limits for an existing bridge:

1. Update the limits in the JSON config
2. Re-run the script on the affected chain(s)

The script will detect that peers are already configured and only update limits if they differ from the on-chain values.

> **Note**: Ownership must not have been transferred yet, or the deployer must be the current owner. If ownership has been transferred to a multisig, rate limit updates must go through the multisig.

## Troubleshooting

### "Current chain not found in NTT config"
The script's `--network` flag doesn't match any `chainId` in the JSON config. Check that the RPC URL points to the correct chain.

### "Transceiver peer address mismatch" after adding a spoke
`setWormholePeer` is irreversible. If set to the wrong address, you need to deploy a new Transceiver.

### Rate limit verification fails
Rate limits are stored as [TrimmedAmounts](https://github.com/wormhole-foundation/native-token-transfers/blob/main/evm/src/libraries/TrimmedAmount.sol) (8 decimal precision for 18-decimal tokens). The `_untrim` helper decodes these back to full precision. Ensure your config limits are specified in full 18-decimal precision (e.g., `"100000000000000000000000"` = 100,000 tokens).

### Ownership already transferred
If the NTT Manager or Transceiver ownership has already been transferred to a multisig, the deployer cannot make further changes. Subsequent configuration changes must go through the multisig.
