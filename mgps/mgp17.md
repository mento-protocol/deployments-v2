## TL;DR

We propose upgrading the BiPoolManager implementation to a new version that adds a `setSpread` function. The currently deployed implementation requires destroying and recreating a pool to change its fee, making fee adjustments operationally expensive. This upgrade enables the contract owner to adjust spread fees directly, starting with a reduction from 5bps to 2bps on select USDm pairs.

---

## Overview

The currently deployed BiPoolManager implementation does not have a `setSpread` function, meaning every fee change requires destroying and recreating the pool with the new fee parameters. This proposal upgrades the BiPoolManager proxy to a new implementation that adds a `setSpread` function, allowing the contract owner to adjust spread fees directly without the overhead of pool destruction and recreation.

The motivation behind this change is to enable fee structure experimentation on Mento collateral pools. The previous 5bps spread fee, introduced via MGP-13, was set to protect reserves from arbitrage losses and generate protocol revenue. However, Mento Labs aims to optimize the fee structure by balancing reserve protection and protocol revenue with keeping Mento competitive in on-chain stablecoin swaps.

### Initial Fee Adjustment

Following this upgrade, Mento Labs plans to reduce spread fees from 5bps to 2bps on:

- USDm to USDC
- USDm to axlUSDC
- USDm to USDT

Ongoing monitoring of swap volume, reserve impact, and protocol revenue will inform further adjustments, communicated via the forum.

For full details, see the forum discussion: [Fee Structure Experimentation on Mento Collateral Pools](https://forum.mento.org/t/fee-structure-experimentation-on-mento-collateral-pools/115)

---

### Security Considerations

**Risk Assessment**

- The upgrade only changes the BiPoolManager implementation; no ownership transfers are involved.
- The governance timelock retains proxy admin ownership of the BiPoolManager.

**Safety Measures**

The new implementation is the same one that was used in [MGP-13: Increase Circuit Breaker to 15bps and Enable 5bps Spread Fee](https://governance.mento.org/proposals/33774473826582746102247872468112299588808192529529153992548885265611575112929), which has already been reviewed and executed successfully. The proxy upgrade mechanism is the same Celo legacy proxy pattern used across all existing Mento V2 contracts.

### Transaction Details

This proposal consists of **1 transaction**.

**Step 1: Upgrade BiPoolManager Implementation (1 transaction)**

Upgrade the BiPoolManager proxy to the new implementation that adds the `setSpread` function.

- Call `_setImplementation(address)` on the BiPoolManager proxy

| Contract      | Address                                    |
| ------------- | ------------------------------------------ |
| BiPoolManager (proxy) | 0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901 |
| New Implementation    | 0xC016174B60519Bdc24433d4ed2cFf6c1efaC7881 |
