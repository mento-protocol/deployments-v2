# Mento Configuration System

The Mento deployment scripts use a contract-based configuration system that allows for flexible, network-specific configurations.

## How it Works

1. **Interface**: `IMentoConfig` defines all configuration structures and getter methods
2. **Base Contract**: `BaseMentoConfig` implements the interface with helper functions
3. **Network Configs**: Each network has its own config contract (e.g., `LocalConfig`, `BaseConfig`)
4. **Access**: Scripts use `Config.get()` to retrieve the configuration

## Usage

### Creating a New Network Configuration

Create a new contract that extends `BaseMentoConfig`:

```solidity
contract MyNetworkConfig is BaseMentoConfig {
    function _initialize() internal override {
        // Set network details
        _networkName = "mynetwork";
        _chainId = 12345;
        
        // Set addresses  
        // Note: addresses will be set by the network-specific config
        
        // Add tokens
        _addToken("USDfx", "Mento Dollar");
        _addToken("EURfx", "Mento Euro");
        
        // Add collateral assets
        _addCollateralAsset(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC on Base
        
        // Add rate feeds - can be between any two assets
        _addRateFeed("USDfx/USDC", "USDfx", "USDC");
        
        // Configure other settings...
    }
}
```

### Using in Deployment Scripts

```solidity
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";

contract MyDeployScript is TrebScript {
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();
        
        // Use configuration
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();
        IMentoConfig.CollateralAsset[] memory collaterals = config.getCollateralAssets();
        // ... etc
    }
}
```

### Setting the Configuration

Set the `MENTO_CONFIG_CONTRACT` environment variable to specify which config to use:

```bash
# Use local config
export MENTO_CONFIG_CONTRACT=LocalConfig

# Use base network config
export MENTO_CONFIG_CONTRACT=BaseConfig

# Run deployment
forge script script/deploy/MyScript.s.sol --rpc-url $RPC_URL --broadcast
```

## Configuration Structures

- **TokenConfig**: Token symbol and name
- **RateFeedConfig**: Rate feed ID and asset pairs
- **CollateralAsset**: Collateral token details
- **ChainlinkRelayerConfig**: Chainlink oracle configuration
- **PoolDefaultConfig**: Default pool parameters
- **TradingLimitsConfig**: Trading limit parameters
- **ReserveConfig**: Reserve configuration
- **BreakerBoxConfig**: Circuit breaker configuration
- **OracleConfig**: Oracle parameters

## Benefits

1. **Type Safety**: All configurations are strongly typed
2. **Network Isolation**: Each network has its own config contract
3. **Reusability**: Common patterns are abstracted in `BaseMentoConfig`
4. **No JSON Parsing**: Eliminates JSON parsing overhead and complexity
5. **Easy Testing**: Config contracts can be easily mocked for tests