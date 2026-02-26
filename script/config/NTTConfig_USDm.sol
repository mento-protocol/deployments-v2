// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INTTConfig} from "./INTTConfig.sol";

/// @notice NTT bridge config for USDm (burn-mint on all chains).
/// @dev USDm is a native stablecoin that can be minted on all chains,
///      so both sides use burning mode. The NTT Manager on each chain
///      needs minter and burner permissions on the token contract.
///
///      Fill in nttManager and transceiver addresses after deploying
///      NTT contracts via the Wormhole NTT CLI.
contract NTTConfig_USDm is INTTConfig {
    function get() external pure override returns (NTTTokenConfig memory config) {
        config.tokenName = "USDm";
        config.tokenDecimals = 18;
        config.rateLimitDuration = 86400; // 24 hours
        config.ownerLabel = "MigrationMultisig";
        config.chains = new ChainConfig[](2);

        // ── Celo (burn-mint) ────────────────────────────────────────────
        uint256[] memory celoInbound = new uint256[](2);
        celoInbound[0] = 0; // self — ignored
        celoInbound[1] = 100_000e18; // from Monad

        config.chains[0] = ChainConfig({
            name: "Celo",
            chainId: 42220,
            wormholeChainId: 14,
            // TODO: fill after NTT CLI deployment
            nttManager: address(0),
            transceiver: address(0),
            token: 0x765DE816845861e75A25fCA122bb6898B8B1282a, // cUSD (StableTokenV2USD)
            isBurning: true,
            outboundLimit: 100_000e18,
            inboundLimits: celoInbound
        });

        // ── Monad (burn-mint) ───────────────────────────────────────────
        uint256[] memory monadInbound = new uint256[](2);
        monadInbound[0] = 100_000e18; // from Celo
        monadInbound[1] = 0; // self — ignored

        config.chains[1] = ChainConfig({
            name: "Monad",
            chainId: 143,
            wormholeChainId: 48,
            // TODO: fill after NTT CLI deployment
            nttManager: address(0),
            transceiver: address(0),
            token: 0x866a7e4611C127DCe1a14C6841D2eA962A68dc88, // StableTokenSpokeUSD
            isBurning: true,
            outboundLimit: 100_000e18,
            inboundLimits: monadInbound
        });
    }
}
