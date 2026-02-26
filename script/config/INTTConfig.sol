// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INTTConfig {
    /// @dev NTT bridge configuration for a single chain in the topology.
    struct ChainConfig {
        string name; // e.g. "Celo", "Monad" — used for logging
        uint256 chainId; // e.g. 42220, 143
        uint16 wormholeChainId; // e.g. 14, 48
        address nttManager; // deployed NTT Manager address
        address transceiver; // deployed Wormhole Transceiver address
        address token; // token address on this chain
        bool isBurning; // false = locking (hub), true = burning (spoke)
        uint256 outboundLimit; // outbound rate limit (full 18-decimal precision)
        uint256[] inboundLimits; // inbound limit from each peer, parallel to chains[]
        //   inboundLimits[i] = limit for traffic from chains[i]
        //   entry at own index is ignored (set to 0)
    }

    /// @dev Full bridge topology for one token across all chains.
    struct NTTTokenConfig {
        string tokenName; // e.g. "USDm", "GBPm"
        uint8 tokenDecimals; // 18
        uint64 rateLimitDuration; // e.g. 86400 (24 hours)
        string ownerLabel; // addressbook key, e.g. "MigrationMultisig"
        ChainConfig[] chains; // all chains in the bridge topology
    }

    function get() external view returns (NTTTokenConfig memory);
}
