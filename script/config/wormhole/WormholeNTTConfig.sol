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
///         The JSON extends the Wormhole NTT CLI output format with fields
///         needed by the setup script: chainId, wormholeChainId, isBurning,
///         tokenName, tokenDecimals, ownerLabel.
///
///         Required env var:
///           WORMHOLE_DEPLOYMENT_FILE — path to the deployment JSON
///             (e.g. "script/deploy/wormhole/configs/USDm.json")
///
///         JSON structure:
///           {
///             "tokenName": "USDm",
///             "tokenDecimals": 18,
///             "ownerLabel": "MigrationMultisig",
///             "chains": {
///               "<ChainName>": {
///                 "chainId": 42220,
///                 "wormholeChainId": 14,
///                 "manager": "0x...",
///                 "transceivers": { "wormhole": { "address": "0x..." } },
///                 "token": "0x...",
///                 "isBurning": true,
///                 "limits": {
///                   "inbound": { "<PeerName>": "100000..." },
///                   "outbound": "100000..."
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

    /// @notice Load and parse the deployment JSON from WORMHOLE_DEPLOYMENT_FILE.
    /// @return config The parsed top-level config.
    /// @return inboundLimits Flattened inbound limits: inboundLimits[i * N + j]
    ///         is the inbound limit on chain i from chain j. Entries where i == j are 0.
    function load() internal view returns (ParsedConfig memory config, uint256[] memory inboundLimits) {
        string memory path = vm.envString("WORMHOLE_DEPLOYMENT_FILE");
        string memory json = vm.readFile(path);

        config.tokenName = vm.parseJsonString(json, ".tokenName");
        config.tokenDecimals = uint8(vm.parseJsonUint(json, ".tokenDecimals"));
        config.ownerLabel = vm.parseJsonString(json, ".ownerLabel");

        // Enumerate chains
        config.chainNames = vm.parseJsonKeys(json, ".chains");
        uint256 n = config.chainNames.length;
        config.chains = new NTTChainConfig[](n);
        inboundLimits = new uint256[](n * n);

        for (uint256 i = 0; i < n; i++) {
            string memory name = config.chainNames[i];
            string memory base = string.concat(".chains.", name);

            config.chains[i] = NTTChainConfig({
                name: name,
                chainId: vm.parseJsonUint(json, string.concat(base, ".chainId")),
                wormholeChainId: uint16(vm.parseJsonUint(json, string.concat(base, ".wormholeChainId"))),
                nttManager: vm.parseJsonAddress(json, string.concat(base, ".manager")),
                transceiver: vm.parseJsonAddress(json, string.concat(base, ".transceivers.wormhole.address")),
                token: vm.parseJsonAddress(json, string.concat(base, ".token")),
                isBurning: vm.parseJsonBool(json, string.concat(base, ".isBurning")),
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
}
