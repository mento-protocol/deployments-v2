// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @dev Per-chain NTT bridge configuration.
///      Token addresses are NOT hardcoded — tokenLabel is resolved at runtime
///      via lookup().
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
///         and resolved at runtime via lookup().
library NTTConfig {
    // ── Chain ID constants ──────────────────────────────────────────────
    uint256 internal constant CELO_EVM_CHAIN_ID = 42220;
    uint16 internal constant CELO_WH_CHAIN_ID = 14;
    uint256 internal constant MONAD_EVM_CHAIN_ID = 143;
    uint16 internal constant MONAD_WH_CHAIN_ID = 48;

    // ── Rate limit constants ────────────────────────────────────────────
    uint256 internal constant USDm_RATE_LIMIT = 500_000e18;
    uint256 internal constant GBPm_RATE_LIMIT = 500_000e18;

    // ── Token config getters ─────────────────────────────────────────────

    /// @notice Returns the full NTT bridge topology for USDm.
    ///         USDm is burn-mint on BOTH Celo and Monad.
    function getUSDmConfig() internal pure returns (NTTTokenConfig memory config) {
        config.tokenName = "USDm";
        config.tokenDecimals = 18;
        config.ownerLabel = "migrationOwner";

        config.chains = new NTTChainConfig[](2);
        config.chains[0] = NTTChainConfig({
            chainName: "celo",
            evmChainId: CELO_EVM_CHAIN_ID,
            wormholeChainId: CELO_WH_CHAIN_ID,
            tokenLabel: "USDm",
            isBurning: true,
            outboundLimit: USDm_RATE_LIMIT
        });
        config.chains[1] = NTTChainConfig({
            chainName: "monad",
            evmChainId: MONAD_EVM_CHAIN_ID,
            wormholeChainId: MONAD_WH_CHAIN_ID,
            tokenLabel: "USDm",
            isBurning: true,
            outboundLimit: USDm_RATE_LIMIT
        });

        config.inboundLimits = new NTTInboundLimit[](2);
        config.inboundLimits[0] = NTTInboundLimit({fromChainName: "monad", limit: USDm_RATE_LIMIT});
        config.inboundLimits[1] = NTTInboundLimit({fromChainName: "celo", limit: USDm_RATE_LIMIT});
    }

    /// @notice Returns the full NTT bridge topology for GBPm.
    ///         GBPm is locking on Celo (hub) and burning on Monad (spoke).
    function getGBPmConfig() internal pure returns (NTTTokenConfig memory config) {
        config.tokenName = "GBPm";
        config.tokenDecimals = 18;
        config.ownerLabel = "migrationOwner";

        config.chains = new NTTChainConfig[](2);
        config.chains[0] = NTTChainConfig({
            chainName: "celo",
            evmChainId: CELO_EVM_CHAIN_ID,
            wormholeChainId: CELO_WH_CHAIN_ID,
            tokenLabel: "GBPm",
            isBurning: false,
            outboundLimit: GBPm_RATE_LIMIT
        });
        config.chains[1] = NTTChainConfig({
            chainName: "monad",
            evmChainId: MONAD_EVM_CHAIN_ID,
            wormholeChainId: MONAD_WH_CHAIN_ID,
            tokenLabel: "GBPm",
            isBurning: true,
            outboundLimit: GBPm_RATE_LIMIT
        });

        config.inboundLimits = new NTTInboundLimit[](2);
        config.inboundLimits[0] = NTTInboundLimit({fromChainName: "monad", limit: GBPm_RATE_LIMIT});
        config.inboundLimits[1] = NTTInboundLimit({fromChainName: "celo", limit: GBPm_RATE_LIMIT});
    }
}
