// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {NTTConfig, NTTTokenConfig, NTTChainConfig, NTTInboundLimit} from "script/config/wormhole/NTTConfig.sol";

/// @title NTTScriptBase
/// @notice Shared base contract for all NTT wormhole scripts, providing
///         config loading and chain resolution helpers.
abstract contract NTTScriptBase is TrebScript {
    uint8 internal tokenDecimals;

    function _loadConfig(string memory _tokenName) internal pure returns (NTTTokenConfig memory) {
        if (keccak256(bytes(_tokenName)) == keccak256("USDm")) {
            return NTTConfig.getUSDmConfig();
        } else if (keccak256(bytes(_tokenName)) == keccak256("GBPm")) {
            return NTTConfig.getGBPmConfig();
        } else {
            revert(string.concat("Unknown token: ", _tokenName));
        }
    }

    function _findMyChain(NTTTokenConfig memory config) internal view returns (NTTChainConfig memory) {
        for (uint256 i = 0; i < config.chains.length; i++) {
            if (config.chains[i].evmChainId == block.chainid) return config.chains[i];
        }
        revert(string.concat("Current chain (", vm.toString(block.chainid), ") not found in NTT config for ", config.tokenName));
    }

    function _findInboundLimit(NTTTokenConfig memory config, string memory fromChainName) internal pure returns (uint256) {
        for (uint256 i = 0; i < config.inboundLimits.length; i++) {
            if (keccak256(bytes(config.inboundLimits[i].fromChainName)) == keccak256(bytes(fromChainName))) {
                return config.inboundLimits[i].limit;
            }
        }
        revert(string.concat("No inbound limit from chain '", fromChainName, "'"));
    }

    function _toBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    /// @dev Decode a TrimmedAmount (uint72) back to a full-precision value.
    ///      TrimmedAmount packs: (amount << 8) | trimmedDecimals
    function _untrim(uint72 packed) internal view returns (uint256) {
        uint8 decimals = uint8(packed & 0xFF);
        uint64 amount = uint64(packed >> 8);
        uint8 td = tokenDecimals;
        if (decimals == td) return uint256(amount);
        if (decimals < td) return uint256(amount) * 10 ** (td - decimals);
        return uint256(amount) / 10 ** (decimals - td);
    }
}
