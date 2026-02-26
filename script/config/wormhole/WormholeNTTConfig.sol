// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vm} from "forge-std/Vm.sol";

/// @dev Per-chain NTT bridge config parsed from JSON.
struct NTTChainConfig {
    string name;
    uint256 chainId;
    uint16 wormholeChainId;
    address nttManager;
    address transceiver;
    address token;
    bool isBurning;
    uint256 outboundLimit;
}

/// @title WormholeNTTConfig
/// @notice Parses a per-token Wormhole NTT deployment JSON into typed structs.
///
///         The JSON follows the Wormhole NTT CLI output format, augmented with
///         extension fields (chainId, wormholeChainId). Token metadata is
///         hardcoded here (all Mento stablecoins are 18 decimals, owned by
///         MigrationMultisig).
///
///         The network (mainnet/testnet) is auto-detected from the chain ID.
///         JSON path: script/config/wormhole/{network}/{tokenName}.json
///
///         JSON structure:
///           {
///             "network": "Mainnet",
///             "chains": {
///               "<ChainName>": {
///                 "chainId": 42220,              // extension
///                 "wormholeChainId": 14,         // extension
///                 "mode": "locking",             // CLI: "locking" or "burning"
///                 "manager": "0x...",            // CLI
///                 "token": "0x...",              // CLI
///                 "transceivers": {              // CLI
///                   "wormhole": { "address": "0x..." }
///                 },
///                 "limits": {                    // wei strings
///                   "outbound": "100000000000000000000000",
///                   "inbound": { "<PeerName>": "100000000000000000000000" }
///                 }
///               }
///             }
///           }
library WormholeNTTConfig {
    address private constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    struct ParsedConfig {
        string tokenName;
        uint8 tokenDecimals;
        string ownerLabel;
        string[] chainNames;
        NTTChainConfig[] chains;
    }

    /// @notice Load and parse a deployment JSON for the given token.
    ///         Auto-detects mainnet/testnet from the chain ID.
    /// @param tokenName The token name (e.g. "USDm"), used to derive the JSON path.
    /// @return config The parsed top-level config.
    /// @return inboundLimits Flattened inbound limits: inboundLimits[i * N + j]
    ///         is the inbound limit on chain i from chain j. Entries where i == j are 0.
    function load(string memory tokenName) internal view returns (ParsedConfig memory config, uint256[] memory inboundLimits) {
        string memory network = wormholeNetworkForChainId(block.chainid);
        string memory jsonPath = string.concat("script/config/wormhole/", network, "/", tokenName, ".json");
        string memory json = vm.readFile(jsonPath);

        config.tokenName = tokenName;
        config.tokenDecimals = 18;
        config.ownerLabel = "MigrationMultisig";

        // Enumerate chains
        config.chainNames = vm.parseJsonKeys(json, ".chains");
        uint256 n = config.chainNames.length;
        config.chains = new NTTChainConfig[](n);
        inboundLimits = new uint256[](n * n);

        for (uint256 i = 0; i < n; i++) {
            string memory name = config.chainNames[i];
            string memory base = string.concat(".chains.", name);

            // CLI uses "mode": "locking" / "burning"
            string memory mode = vm.parseJsonString(json, string.concat(base, ".mode"));
            bool isBurning = keccak256(bytes(mode)) == keccak256("burning");

            config.chains[i] = NTTChainConfig({
                name: name,
                chainId: vm.parseJsonUint(json, string.concat(base, ".chainId")),
                wormholeChainId: uint16(vm.parseJsonUint(json, string.concat(base, ".wormholeChainId"))),
                nttManager: vm.parseJsonAddress(json, string.concat(base, ".manager")),
                transceiver: vm.parseJsonAddress(json, string.concat(base, ".transceivers.wormhole.address")),
                token: vm.parseJsonAddress(json, string.concat(base, ".token")),
                isBurning: isBurning,
                outboundLimit: vm.parseUint(vm.parseJsonString(json, string.concat(base, ".limits.outbound")))
            });

            // Parse inbound limits from each peer
            for (uint256 j = 0; j < n; j++) {
                if (j == i) continue;
                string memory inboundPath = string.concat(base, ".limits.inbound.", config.chainNames[j]);
                inboundLimits[i * n + j] = vm.parseUint(vm.parseJsonString(json, inboundPath));
            }
        }

        // Validate addresses
        for (uint256 i = 0; i < n; i++) {
            NTTChainConfig memory c = config.chains[i];
            require(c.nttManager != address(0), string.concat(c.name, ": manager is zero address"));
            require(c.transceiver != address(0), string.concat(c.name, ": transceiver is zero address"));
            require(c.token != address(0), string.concat(c.name, ": token is zero address"));
        }
    }

    /// @dev Map chain ID to network directory name. Reverts for unknown chains.
    function wormholeNetworkForChainId(uint256 cid) internal pure returns (string memory) {
        // Mainnet
        if (cid == 42220) return "mainnet"; // Celo
        if (cid == 143) return "mainnet"; // Monad
        // Testnet
        if (cid == 11155111) return "testnet"; // Ethereum Sepolia
        if (cid == 44787) return "testnet"; // Celo Alfajores (Sepolia)
        if (cid == 10143) return "testnet"; // Monad Testnet
        revert("WormholeNTTConfig: unknown chain ID, add it to wormholeNetworkForChainId()");
    }
}
