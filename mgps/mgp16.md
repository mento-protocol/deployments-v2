## TL;DR

Following the successful Mento V3 deployment and the migration of GBPm to the CDP model, we propose for CHFm and JPYm to be the next stable tokens to be migrated. We ask governance to temporarily transfer the `owner` role for CHFm and JPYm to the 4/7 Mento Labs Dev Multisig to execute this migration.

---

## Overview

With GBPm now CDP-backed after the migration to Mento V3, we propose to migrate CHFm and JPYm following the same process. This involves upgrading the token implementations to StableTokenV3, deploying FPMM pools, and deprecating the Mento V2 exchange pools.

---

### Security Considerations

**Risk Assessment**

- Temporary centralization of ownership on CHFm and JPYm to the Mento Labs Dev Multisig.
- Limited scope: only CHFm and JPYm token contracts.
- The same process was successfully executed for GBPm with no incidents.

**Safety Measures**

We will employ the same operational safety measures used throughout Phase 1 and the Mento Reserve multisig operations over the past 3 years, with 0 incidents.

**Transparency Commitments**

1. Public announcement before any transaction associated with this upgrade.
2. Technical details of changes are published on the forum.
3. Transaction hashes shared for community verification on the forum.

### Transaction Details

This proposal consists of **4 transactions**, which transfer ownership of CHFm and JPYm to the 4/7 Mento Labs Dev Multisig (`0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458`).

**Step 1: Transfer Stable Token Ownership (4 transactions)**

Transfer both the proxy admin and contract ownership for each stable token to the Dev Multisig. Proxy admin ownership is required to upgrade the token implementations to StableTokenV3, while contract ownership is required to configure the new minter/burner roles needed by Mento V3.

For each of CHFm and JPYm:

- Call `_transferOwnership(address)` on the token proxy to transfer proxy admin ownership
- Call `transferOwnership(address)` on the token contract to transfer contract ownership

| Token | Address                                    |
| ----- | ------------------------------------------ |
| CHFm  | 0xb55a79F398E759E43C95b979163f30eC87Ee131D |
| JPYm  | 0xc45eCF20f3CD864B32D9794d6f76814aE8892e20 |
