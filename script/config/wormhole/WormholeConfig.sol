// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WormholeNTTConfig, NTTChainConfig} from "./WormholeNTTConfig.sol";

/// @title WormholeConfig
/// @notice Abstract base for per-network Wormhole NTT token registrations.
///         Concrete configs (e.g. WormholeConfig_mainnet) call _registerToken()
///         in their constructor to declare each token's metadata. The JSON
///         deployment files are read lazily when get() is called.
///
///         Usage:
///           WormholeConfig cfg = WormholeConfig(vm.deployCode("WormholeConfig_mainnet"));
///           (WormholeNTTConfig.ParsedConfig memory c, uint256[] memory limits) = cfg.get("USDm");
abstract contract WormholeConfig {
    struct TokenRegistration {
        uint8 decimals;
        string ownerLabel;
        bool registered;
    }

    mapping(bytes32 => TokenRegistration) private _tokens;

    function _registerToken(string memory name, uint8 decimals, string memory ownerLabel) internal {
        _tokens[keccak256(bytes(name))] = TokenRegistration(decimals, ownerLabel, true);
    }

    /// @notice Get the full parsed config for a registered token.
    ///         Reads the JSON at script/config/wormhole/{tokenName}.json and
    ///         combines it with the registered metadata.
    function get(string memory tokenName)
        public
        view
        returns (WormholeNTTConfig.ParsedConfig memory config, uint256[] memory inboundLimits)
    {
        bytes32 key = keccak256(bytes(tokenName));
        TokenRegistration memory reg = _tokens[key];
        require(reg.registered, string.concat("WormholeConfig: token not registered: ", tokenName));

        string memory jsonPath = string.concat("script/config/wormhole/", tokenName, ".json");
        return WormholeNTTConfig.load(jsonPath, tokenName, reg.decimals, reg.ownerLabel);
    }
}
