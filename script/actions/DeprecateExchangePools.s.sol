// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IVirtualPoolFactory} from "lib/mento-core/contracts/interfaces/IVirtualPoolFactory.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";

/**
 * @title DeprecateExchangePools
 * @notice Deprecates every exchange flagged `deprecated: true` in the network config.
 *         For each flagged exchange, in order:
 *           1. Deprecate its VirtualPool on the VirtualPoolFactory (if one exists), cutting the
 *              pair out of MentoRouter routing before the underlying exchange disappears.
 *           2. Destroy the exchange on the BiPoolManager.
 */
contract DeprecateExchangePools is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders migrationOwner
    /// @custom:env {bytes32:optional} exchangeId
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        address biPoolManager = lookupProxyOrFail("BiPoolManager");
        bytes32 pickedExchangeId = vm.envOr("exchangeId", bytes32(0));

        IMentoConfig.ExchangeConfig[] memory exchanges = config.getExchanges();
        uint256 flagged;

        for (uint256 i = 0; i < exchanges.length; i++) {
            IMentoConfig.ExchangeConfig memory exchange = exchanges[i];
            if (!exchange.deprecated) continue;

            address asset0 = exchange.pool.asset0;
            address asset1 = exchange.pool.asset1;

            // On-chain exchangeIds are hashed from token symbols at creation time, and symbols
            // have since been renamed — so the id cannot be recomputed from config. Match live
            // exchanges by assets + pricing module instead (same approach as ExchangeVerification).
            (bytes32 exchangeId, uint256 index, bool live) =
                _findLiveExchange(biPoolManager, asset0, asset1, address(exchange.pool.pricingModule));

            if (pickedExchangeId != bytes32(0) && exchangeId != pickedExchangeId) continue;
            flagged++;

            console.log(
                string.concat(
                    "\nExchange (",
                    _pairName(asset0, asset1),
                    ", id: ",
                    live ? vm.toString(exchangeId) : "not found on-chain",
                    ")"
                )
            );

            _deprecateVirtualPool(owner, asset0, asset1);

            if (!live) {
                console.log("   ...skipping exchange destroy: not found on-chain (already destroyed)");
                continue;
            }

            console.log("   ...destroying v2 exchange");
            IBiPoolManager(owner.harness(biPoolManager)).destroyExchange(exchangeId, index);
        }

        if (flagged == 0) {
            console.log("No exchanges flagged `deprecated: true` in config; nothing to do.");
        }
    }

    /// @dev Step 1: remove the pair from Router routing before the underlying exchange disappears.
    ///      If the VirtualPool outlived the exchange, its reserve views would silently return zeros.
    function _deprecateVirtualPool(Senders.Sender storage owner, address asset0, address asset1) internal {
        address factory = lookup("VirtualPoolFactory:v3.0.0");
        if (factory == address(0)) {
            console.log("   ...skipping virtual pool: no VirtualPoolFactory deployed");
            return;
        }

        address pool = IVirtualPoolFactory(factory).getPool(asset0, asset1);
        if (pool == address(0)) {
            console.log("   ...skipping virtual pool: pair has no virtual pool");
            return;
        }

        if (IVirtualPoolFactory(factory).isPoolDeprecated(pool)) {
            console.log(string.concat("   ...skipping virtual pool: ", vm.toString(pool), " already deprecated"));
            return;
        }

        console.log(string.concat("   ...deprecating virtual pool ", vm.toString(pool)));
        IVirtualPoolFactory(owner.harness(factory)).deprecatePool(pool);
    }

    /// @dev Finds a live exchange by assets + pricing module and returns its on-chain id and index.
    ///      Called right before every destroy because destroyExchange uses swap-and-pop, which
    ///      reorders the exchangeIds array on each removal.
    function _findLiveExchange(address biPoolManager, address asset0, address asset1, address pricingModule)
        internal
        view
        returns (bytes32 exchangeId, uint256 index, bool live)
    {
        bytes32[] memory ids = IBiPoolManager(biPoolManager).getExchangeIds();
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(ids[i]);
            bool assetsMatch =
                (pool.asset0 == asset0 && pool.asset1 == asset1) || (pool.asset0 == asset1 && pool.asset1 == asset0);
            if (assetsMatch && address(pool.pricingModule) == pricingModule) {
                return (ids[i], i, true);
            }
        }
    }

    function _pairName(address asset0, address asset1) internal view returns (string memory) {
        return string.concat(IERC20Metadata(asset0).symbol(), "/", IERC20Metadata(asset1).symbol());
    }
}
