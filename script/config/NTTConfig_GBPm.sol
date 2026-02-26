// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INTTConfig} from "./INTTConfig.sol";

/// @notice NTT bridge config for GBPm (hub-spoke / locking mode).
/// @dev GBPm uses a single lockbox on Celo (hub) and burn-mint on spokes.
///      Celo locks tokens (isBurning=false), spokes burn/mint (isBurning=true).
///      Only burning-mode chains need minter/burner permissions.
///
///      Fill in nttManager and transceiver addresses after deploying
///      NTT contracts via the Wormhole NTT CLI.
contract NTTConfig_GBPm is INTTConfig {
    function get() external pure override returns (NTTTokenConfig memory config) {
        config.tokenName = "GBPm";
        config.tokenDecimals = 18;
        config.rateLimitDuration = 86400; // 24 hours
        config.ownerLabel = "MigrationMultisig";
        config.chains = new ChainConfig[](2);

        // ── Celo (hub / locking) ────────────────────────────────────────
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
            token: 0xCCF663b1fF11028f0b19058d0f7B674004a40746, // StableTokenV2GBP
            isBurning: false,
            outboundLimit: 100_000e18,
            inboundLimits: celoInbound
        });

        // ── Monad (spoke / burning) ─────────────────────────────────────
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
            token: 0xddF082068Caa5B941ED8c603ADf0cecBdBb59f8E, // StableTokenSpokeGBP
            isBurning: true,
            outboundLimit: 100_000e18,
            inboundLimits: monadInbound
        });
    }
}
