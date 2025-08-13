# Mento Protocol Deployment Guide

This document describes the deployment and configuration steps for spinning up a full instance of the Mento Protocol on any target network using treb.

## Overview

The Mento Protocol is a decentralized stablecoin platform that enables the creation and management of multiple stable assets backed by various collateral types. The deployment process involves multiple smart contracts that work together to provide price stability, liquidity, and governance.

## Architecture Components

### Core Protocol Components

1. **ProxyAdmin**: Manages upgradeable proxy contracts across the protocol
2. **Broker**: Central swap execution engine that routes trades between users and exchange providers
3. **Stable Tokens**: ERC20 stable assets (USDfx, EURfx, BRLfx, etc.) representing different fiat currencies
4. **Reserve**: Holds and manages collateral assets with spending controls
5. **SortedOracles**: Aggregates price feeds from multiple oracle sources
6. **BreakerBox**: Circuit breaker system for risk management
7. **BiPoolManager**: AMM exchange provider managing two-asset trading pools
8. **Pricing Modules**: Different AMM pricing algorithms (Constant Product, Constant Sum)

### Supporting Infrastructure

- **AddressSortedLinkedListWithMedian**: Data structure for efficient median calculations
- **MedianDeltaBreaker**: Circuit breaker triggered by rapid median price changes
- **ValueDeltaBreaker**: Circuit breaker triggered by individual price report deviations
- **ChainlinkRelayerFactory**: Factory for creating Chainlink price feed adapters (optional)

### Governance Components (Optional)

- **MentoToken**: Governance token for the protocol
- **MentoGovernor**: On-chain governance contract
- **TimelockController**: Time-delayed execution for governance proposals
- **Locking**: Vote-escrowed locking mechanism for governance power
- **Emission**: Token emission schedule management
- **Airgrab**: Token distribution mechanism

## Deployment Order and Dependencies

The deployment must follow a specific order due to contract dependencies:

### Phase 1: Core Infrastructure
1. **ProxyAdmin**
   - No dependencies
   - Manages all upgradeable contracts
   
2. **AddressSortedLinkedListWithMedian**
   - No dependencies
   - Required by SortedOracles

### Phase 2: Oracle System
3. **SortedOracles** (Implementation + Proxy)
   - Dependencies: AddressSortedLinkedListWithMedian
   - Initialization: `reportExpirySeconds` (e.g., 60 seconds)

4. **BreakerBox**
   - Dependencies: SortedOracles
   - Initialization: Empty rate feeds array, SortedOracles address

5. **Breakers** (MedianDeltaBreaker, ValueDeltaBreaker)
   - Dependencies: SortedOracles, BreakerBox
   - Configuration: Cooldown times, rate change thresholds
   - Post-deployment: Register with BreakerBox

### Phase 3: Exchange Infrastructure
6. **Broker** (Implementation + Proxy)
   - Dependencies: ProxyAdmin
   - Initialization: Empty arrays for exchange providers and reserves

7. **Reserve** (Implementation + Proxy)
   - Dependencies: ProxyAdmin
   - Initialization: Asset allocation, spending ratios, tobin tax parameters

8. **Pricing Modules**
   - No dependencies
   - Deploy both ConstantProductPricingModule and ConstantSumPricingModule

### Phase 4: Stable Tokens
9. **StableTokenV2** (Implementation)
   - No dependencies
   - Single implementation for all stable tokens

10. **Stable Token Proxies** (One per currency)
    - Dependencies: StableTokenV2 implementation, ProxyAdmin
    - Currencies: USDfx, EURfx, BRLfx, XOFfx, KESfx, COPfx, PHPfx, CADfx, GBPfx, CHFfx, JPYfx, AUDfx, GHSfx, INRfx, NGNfx, ZARfx
    - Two-step initialization:
      - `initialize()`: Set name, symbol, initial balances
      - `initializeV2()`: Link to Broker, set validators

### Phase 5: Exchange Provider
11. **BiPoolManager** (Implementation + Proxy)
    - Dependencies: Broker, Reserve, SortedOracles, BreakerBox, Pricing Modules
    - Initialization: Links to all dependent contracts

### Phase 6: Configuration

12. **Oracle Configuration**
    - Add oracle addresses to SortedOracles
    - Configure rate feed IDs for each trading pair
    - Set token-specific report expiry times if needed

13. **Breaker Configuration**
    - Configure rate change thresholds per asset
    - Set cooldown periods
    - Enable breakers for specific rate feeds

14. **Pool Configuration**
    - Create exchange pools in BiPoolManager
    - Configure spread, initial bucket sizes
    - Link pricing modules to pools
    - Update virtual pool sizes based on oracle prices

15. **Broker Configuration**
    - Add BiPoolManager as exchange provider
    - Map exchange provider to Reserve
    - Configure trading limits per exchange

16. **Reserve Configuration**
    - Add collateral assets
    - Set daily spending ratios
    - Configure reserve ratios
    - Add stable tokens as known tokens

## Post-Deployment Setup

### 1. Oracle Setup
```
- Add authorized oracle addresses to SortedOracles
- Configure rate feed IDs (e.g., "USDfx/CELO", "EURfx/CELO")
- Set up oracle reporting infrastructure
```

### 2. Liquidity Provision
```
- Transfer collateral assets to Reserve
- Set up initial exchange pools with appropriate sizes
- Configure spreads based on market conditions
```

### 3. Trading Limits
```
- Configure L0/L1/LG limits in Broker for each exchange
- Set time windows for limit resets
- Adjust based on liquidity and risk parameters
```

### 4. Circuit Breakers
```
- Set appropriate thresholds for MedianDeltaBreaker (e.g., 10% in 5 minutes)
- Configure ValueDeltaBreaker for individual report validation
- Test breaker triggers and recovery
```

### 5. Access Control
```
- Transfer ownership of contracts to appropriate parties
- Set up multisig for critical functions
- Configure role-based permissions
```

## Configuration Parameters

### SortedOracles
- `reportExpirySeconds`: Default timeout for price reports (e.g., 300 seconds)
- Per-token specific timeouts can be configured

### BreakerBox
- Trading modes: 0 (bidirectional), 1 (inflow only), 2 (outflow only), 3 (trading halted)
- Rate feed dependencies for cascading halts

### Reserve
- `spendingRatio`: Daily spending limit as fraction (e.g., 1e24 = 100%)
- `tobinTax`: Transaction tax rate
- `tobinTaxReserveRatio`: Reserve ratio threshold for tax activation

### BiPoolManager
- `spread`: Buy/sell spread per pool (e.g., 1e16 = 1%)
- `referenceRateFeedID`: Oracle price feed for pool rebalancing
- `stablePoolResetSize`: Target stable token bucket size

### Broker
- `tradingLimitsConfig`: L0 (per-trade), L1 (short window), LG (long window) limits
- Time windows for limit resets

## Security Considerations

1. **Gradual Rollout**: Start with conservative parameters and limited liquidity
2. **Oracle Diversity**: Ensure multiple independent oracle sources
3. **Circuit Breaker Testing**: Verify breakers trigger appropriately
4. **Access Control**: Use timelocks and multisigs for admin functions
5. **Monitoring**: Set up comprehensive monitoring for all components

## Governance Deployment (Optional)

If deploying with governance:

1. Deploy GovernanceFactory
2. Use factory to deploy full governance suite:
   - MentoToken
   - Locking
   - MentoGovernor
   - TimelockController
   - Emission
   - Airgrab
3. Configure voting parameters and timelock delays
4. Set up initial token distribution

## Verification Checklist

- [ ] All contracts deployed and verified on block explorer
- [ ] Proxy admin ownership transferred to multisig
- [ ] Oracle feeds active and reporting
- [ ] Circuit breakers configured and tested
- [ ] Initial liquidity provided to pools
- [ ] Trading limits set appropriately
- [ ] Access controls configured
- [ ] Monitoring infrastructure active