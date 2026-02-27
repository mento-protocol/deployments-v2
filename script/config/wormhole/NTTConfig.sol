// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @dev Per-chain NTT bridge configuration.
///      Token addresses are NOT hardcoded — tokenLabel is resolved at runtime
///      via lookupAddressbook().
struct NTTChainConfig {
    string chainName;
    uint256 evmChainId;
    uint16 wormholeChainId;
    string tokenLabel;
    bool isBurning;
    uint256 outboundLimit;
}

/// @dev Inbound rate limit from a specific peer chain.
struct NTTInboundLimit {
    string fromChainName;
    uint256 limit;
}

/// @dev Complete NTT bridge configuration for one token across all chains.
struct NTTTokenConfig {
    string tokenName;
    uint8 tokenDecimals;
    string ownerLabel;
    NTTChainConfig[] chains;
    NTTInboundLimit[] inboundLimits;
}

/// @title NTTConfig
/// @notice Typed Solidity configuration for NTT bridge deployments.
///         Replaces JSON-based WormholeNTTConfig with compile-time checked topology.
///         Token and owner addresses are stored as addressbook labels (strings)
///         and resolved at runtime via lookupAddressbook().
library NTTConfig {
    // ── Chain ID constants ──────────────────────────────────────────────
    uint256 internal constant CELO_EVM_CHAIN_ID = 42220;
    uint16 internal constant CELO_WH_CHAIN_ID = 14;
    uint256 internal constant MONAD_EVM_CHAIN_ID = 143;
    uint16 internal constant MONAD_WH_CHAIN_ID = 48;

    // ── Rate limit constants ────────────────────────────────────────────
    uint256 internal constant DEFAULT_RATE_LIMIT = 100_000e18;
}
