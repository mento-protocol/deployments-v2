# Mento Cross-Chain Deployment

This repository contains the deployment scripts and configuration for deploying the Mento Protocol across multiple blockchain networks. The Mento Protocol is a decentralized exchange protocol that enables the creation and trading of stable assets.

## Overview

This project provides a comprehensive framework for deploying Mento Protocol instances with:

- Multiple stable tokens (cUSD, cEUR, cREAL, etc.)
- Various collateral assets (CELO, USDC, USDT, axlUSDC, axlEUROC)
- Configurable exchange pools with different pricing modules
- Oracle integration for price feeds
- Circuit breakers for risk management
- Governance configuration

## Project Structure

```plain
├── script/
│   ├── actions/                     # Actions, one-off dev utils
│   ├── config/
│   │   ├── MentoConfig.sol          # Base configuration contract
│   │   └── MentoConfig_celo_sepolia.sol  # Celo Sepolia testnet configuration
│   ├── deploy/                      # Component deployment scripts
│   ├── helpers/                     # Utility contracts, helper libraries
│   ├── protocol.yaml                # Mento Protocol deployment compose file
│   └── governance.yaml              # Mento Governance deployment compose file
└── lib/
    └── mento-core/                  # Core Mento Protocol contracts
```

## Supported Assets

### Stable Tokens

- **cUSD** - Celo Dollar
- **cEUR** - Celo Euro
- **cREAL** - Celo Brazilian Real
- **eXOF** - ECO CFA
- **cKES** - Celo Kenyan Shilling
- **PUSO** - Philippine Peso Stablecoin
- **cCOP** - Celo Colombian Peso
- **cGHS** - Celo Ghanaian Cedi
- **cGBP** - Celo British Pound
- **cZAR** - Celo South African Rand
- **cCAD** - Celo Canadian Dollar
- **cAUD** - Celo Australian Dollar
- **cCHF** - Celo Swiss Franc
- **cJPY** - Celo Japanese Yen
- **cNGN** - Celo Nigerian Naira

### Collateral Assets

- **CELO** - Native Celo token
- **USDC** - USD Coin
- **USDT** - Tether USD
- **axlUSDC** - Axelar USDC
- **axlEUROC** - Axelar EUROC

## Exchange Pools

The protocol supports 19 configured exchange pools with two types of pricing modules:

1. **Constant Sum Pricing Module** - For stable-to-stable swaps (e.g., cUSD/USDC)
2. **Constant Product Pricing Module** - For volatile pairs (e.g., cUSD/CELO)

Each pool has configurable:

- Spread percentages
- Rate feed oracles
- Reset frequencies
- Trading limits (5-minute, daily, and global limits)

## Oracle Configuration

The system uses Chainlink-compatible oracle feeds with:

- Value-based circuit breakers
- Median-based circuit breakers
- Configurable cooldown periods and thresholds
- Mock aggregators for testnet deployments

## Deployment

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [treb](https://github.com/trebuchet-org/treb-cli) installed for managing deployments
- Node.js and npm (for dependencies)
- Access to target network RPC endpoint

### Installation

```bash
# Clone the repository
git clone https://github.com/mento-protocol/mento-deployments-v2
cd mento-deployments-v2

# Create a local .env based on the .env.example and fill out the empty values
cp .env.example .env

# Install dependencies
forge install

# Install the celo contracts
cd lib/mento-core && npm install

# Update submodules
git submodule update --init --recursive
```

### Deploy to Testnet

We deploy using [treb](https://github.com/trebuchet-org/treb-cli).

```bash
# Run deployment
treb compose script/protocol.yaml -n <testnet> -n <namespace>
```

## Configuration

The main configuration is handled through network-specific config contracts (e.g., `MentoConfig_celo_sepolia.sol`). These contracts define:

- **Token Configuration**: Stable tokens and collateral assets
- **Oracle Configuration**: Price feeds and circuit breakers
- **Swap Configuration**: Exchange pools and trading limits
- **Governance Configuration**: Timelock delays, voting periods, and quorum requirements

### Trading Limits

Trading limits are organized in tiers:

- **Tier 1**: 100k/500k/2.5M USD limits
- **Tier 2**: 50k/250k/1.25M USD limits

Limits are applied per timestep (5 minutes and 1 day) with global caps.

## Development

### Building

```bash
forge build
```

### Formatting

```bash
forge fmt
```

## Security

- All price feeds include circuit breakers for protection against oracle failures
- Trading limits prevent large-scale manipulation
- Governance timelock ensures changes are transparent and delayed
- Regular security audits are conducted on the protocol

## License

This project is licensed under the MIT License

## Support

For questions and support:

- Open an issue in this repository
- Join the Mento Discord community
- Visit [mento.org](https://mento.org) for more information
