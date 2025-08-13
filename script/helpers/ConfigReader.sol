// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";

/**
 * @title ConfigReader
 * @notice Helper library to read configuration from variables.json
 */
abstract contract ConfigReader is TrebScript {
    using stdJson for string;

    struct TokenConfig {
        string symbol;
        string name;
    }

    struct RateFeedConfig {
        string id; // e.g., "USDfx/CELO"
        string asset0;
        string asset1;
    }

    struct ChainlinkAggregatorConfig {
        address aggregator;
        bool invert;
    }

    struct ChainlinkRelayerConfig {
        string rateFeedId; // e.g., "USDfx/CELO"
        string rateFeedDescription; // e.g., "USDfx/CELO"
        uint256 maxTimestampSpread;
        ChainlinkAggregatorConfig[] aggregators;
    }

    struct CollateralAsset {
        string symbol;
        address addr;
        uint8 decimals;
    }

    struct PoolDefaultConfig {
        uint256 defaultSpread;
        uint256 defaultBucketSize;
        uint256 minimumReports;
        uint256 referenceRateResetFrequency;
        uint256 stablePoolResetSize;
        string pricingModule;
    }

    struct TradingLimitsConfig {
        uint32 timestep0;
        uint32 timestep1;
        int48 limit0;
        int48 limit1;
        int48 limitGlobal;
        uint8 flags;
    }

    struct ReserveConfig {
        uint256 tobinTaxStalenessThreshold;
        uint256 spendingRatio;
        uint256 frozenGold;
        uint256 frozenDays;
        bytes32[] assetAllocationSymbols;
        uint256[] assetAllocationWeights;
        uint256 tobinTax;
        uint256 tobinTaxReserveRatio;
        uint256[] collateralAssetDailySpendingRatios;
    }

    string internal configPath;
    string internal configJson;

    function loadConfig() internal {
        // Get config path from environment variable
        try vm.envString("MENTO_CONFIG") returns (string memory envPath) {
            configPath = envPath;
        } catch {
            configPath = "script/networks/base.json";
        }

        // Read the JSON file
        configJson = vm.readFile(configPath);
        console.log("Loaded config from:", configPath);
    }

    // Network configuration
    function getChainId() internal view returns (uint256) {
        return configJson.readUint(".network.chainId");
    }

    function getNetworkName() internal view returns (string memory) {
        return configJson.readString(".network.name");
    }

    // Addresses
    function getDeployer() internal view returns (address) {
        return configJson.readAddress(".addresses.deployer");
    }

    function getGovernance() internal view returns (address) {
        return configJson.readAddress(".addresses.governance");
    }

    function getCeloToken() internal view returns (address) {
        return configJson.readAddress(".addresses.celoToken");
    }

    function getOracleAddresses() internal view returns (address[] memory) {
        return configJson.readAddressArray(".addresses.oracles");
    }

    function getCollateralAssets()
        internal
        view
        returns (CollateralAsset[] memory)
    {
        uint256 length = configJson.readUint(
            ".addresses.collateralAssets.length"
        );
        CollateralAsset[] memory assets = new CollateralAsset[](length);

        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string(
                abi.encodePacked(
                    ".addresses.collateralAssets[",
                    vm.toString(i),
                    "]"
                )
            );
            assets[i] = CollateralAsset({
                symbol: configJson.readString(
                    string(abi.encodePacked(basePath, ".symbol"))
                ),
                addr: configJson.readAddress(
                    string(abi.encodePacked(basePath, ".address"))
                ),
                decimals: uint8(
                    configJson.readUint(
                        string(abi.encodePacked(basePath, ".decimals"))
                    )
                )
            });
        }

        return assets;
    }

    // Token configuration
    function getTokenConfigs() internal view returns (TokenConfig[] memory) {
        uint256 length = configJson.readUint(".tokens.length");
        TokenConfig[] memory tokens = new TokenConfig[](length);

        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string(
                abi.encodePacked(".tokens[", vm.toString(i), "]")
            );
            tokens[i] = TokenConfig({
                symbol: configJson.readString(
                    string(abi.encodePacked(basePath, ".symbol"))
                ),
                name: configJson.readString(
                    string(abi.encodePacked(basePath, ".name"))
                )
            });
        }

        return tokens;
    }

    // Oracle configuration
    function getReportExpirySeconds() internal view returns (uint256) {
        return configJson.readUint(".oracle.reportExpirySeconds");
    }

    // Reserve configuration
    function getReserveConfig() internal view returns (ReserveConfig memory) {
        // Read asset allocation arrays
        string[] memory symbolStrings = configJson.readStringArray(
            ".reserve.assetAllocationSymbols"
        );
        bytes32[] memory symbols = new bytes32[](symbolStrings.length);
        for (uint256 i = 0; i < symbolStrings.length; i++) {
            symbols[i] = bytes32(bytes(symbolStrings[i]));
        }

        return
            ReserveConfig({
                tobinTaxStalenessThreshold: configJson.readUint(
                    ".reserve.tobinTaxStalenessThreshold"
                ),
                spendingRatio: configJson.readUint(".reserve.spendingRatio"),
                frozenGold: configJson.readUint(".reserve.frozenGold"),
                frozenDays: configJson.readUint(".reserve.frozenDays"),
                assetAllocationSymbols: symbols,
                assetAllocationWeights: configJson.readUintArray(
                    ".reserve.assetAllocationWeights"
                ),
                tobinTax: configJson.readUint(".reserve.tobinTax"),
                tobinTaxReserveRatio: configJson.readUint(
                    ".reserve.tobinTaxReserveRatio"
                ),
                collateralAssetDailySpendingRatios: configJson.readUintArray(
                    ".reserve.collateralAssetDailySpendingRatios"
                )
            });
    }

    // Broker configuration
    function getTradingLimitsConfig()
        internal
        view
        returns (TradingLimitsConfig memory)
    {
        return
            TradingLimitsConfig({
                timestep0: uint32(
                    configJson.readUint(".broker.tradingLimits.timestep0")
                ),
                timestep1: uint32(
                    configJson.readUint(".broker.tradingLimits.timestep1")
                ),
                limit0: int48(
                    uint48(configJson.readUint(".broker.tradingLimits.limit0"))
                ),
                limit1: int48(
                    uint48(configJson.readUint(".broker.tradingLimits.limit1"))
                ),
                limitGlobal: int48(
                    uint48(
                        configJson.readUint(".broker.tradingLimits.limitGlobal")
                    )
                ),
                flags: uint8(configJson.readUint(".broker.tradingLimits.flags"))
            });
    }

    // Pool configuration
    function getPoolDefaultConfig()
        internal
        view
        returns (PoolDefaultConfig memory)
    {
        return
            PoolDefaultConfig({
                defaultSpread: configJson.readUint(".pools.defaultSpread"),
                defaultBucketSize: configJson.readUint(
                    ".pools.defaultBucketSize"
                ),
                minimumReports: configJson.readUint(".pools.minimumReports"),
                referenceRateResetFrequency: configJson.readUint(
                    ".pools.referenceRateResetFrequency"
                ),
                stablePoolResetSize: configJson.readUint(
                    ".pools.stablePoolResetSize"
                ),
                pricingModule: configJson.readString(".pools.pricingModule")
            });
    }

    // Breaker configuration
    function getBreakerCooldownTime() internal view returns (uint256) {
        return configJson.readUint(".breakerBox.defaultCooldownTime");
    }

    // Rate feed configuration
    function getRateFeedConfigs()
        internal
        view
        returns (RateFeedConfig[] memory)
    {
        uint256 length = configJson.readUint(".rateFeeds.length");
        RateFeedConfig[] memory rateFeeds = new RateFeedConfig[](length);

        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string(
                abi.encodePacked(".rateFeeds[", vm.toString(i), "]")
            );
            rateFeeds[i] = RateFeedConfig({
                id: configJson.readString(
                    string(abi.encodePacked(basePath, ".id"))
                ),
                asset0: configJson.readString(
                    string(abi.encodePacked(basePath, ".asset0"))
                ),
                asset1: configJson.readString(
                    string(abi.encodePacked(basePath, ".asset1"))
                )
            });
        }

        return rateFeeds;
    }

    // Helper to get rate feed ID from asset pair
    function getRateFeedId(
        string memory asset0,
        string memory asset1
    ) internal pure returns (address) {
        string memory pair = string(abi.encodePacked(asset0, "/", asset1));
        return address(uint160(uint256(keccak256(abi.encodePacked(pair)))));
    }

    // Helper to get rate feed ID from string like "USDfx/CELO"
    function getRateFeedIdFromString(string memory feedId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(feedId)))));
    }

    // Chainlink relayer configuration
    function getChainlinkRelayerConfigs() public view returns (ChainlinkRelayerConfig[] memory) {
        // Note: If chainlinkRelayers is not in the config, readUint will revert
        // The calling script should handle this case
        uint256 length = configJson.readUint(".chainlinkRelayers.length");
        
        if (length == 0) return new ChainlinkRelayerConfig[](0);
        
        ChainlinkRelayerConfig[] memory relayers = new ChainlinkRelayerConfig[](length);
        
        for (uint256 i = 0; i < length; i++) {
            string memory basePath = string(abi.encodePacked(".chainlinkRelayers[", vm.toString(i), "]"));
            
            // Read aggregator configs
            uint256 aggLength = configJson.readUint(string(abi.encodePacked(basePath, ".aggregators.length")));
            ChainlinkAggregatorConfig[] memory aggregators = new ChainlinkAggregatorConfig[](aggLength);
            
            for (uint256 j = 0; j < aggLength; j++) {
                string memory aggPath = string(abi.encodePacked(basePath, ".aggregators[", vm.toString(j), "]"));
                aggregators[j] = ChainlinkAggregatorConfig({
                    aggregator: configJson.readAddress(string(abi.encodePacked(aggPath, ".aggregator"))),
                    invert: configJson.readBool(string(abi.encodePacked(aggPath, ".invert")))
                });
            }
            
            relayers[i] = ChainlinkRelayerConfig({
                rateFeedId: configJson.readString(string(abi.encodePacked(basePath, ".rateFeedId"))),
                rateFeedDescription: configJson.readString(string(abi.encodePacked(basePath, ".rateFeedDescription"))),
                maxTimestampSpread: configJson.readUint(string(abi.encodePacked(basePath, ".maxTimestampSpread"))),
                aggregators: aggregators
            });
        }
        
        return relayers;
    }
}
