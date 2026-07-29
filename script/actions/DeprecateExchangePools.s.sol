// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IVirtualPoolFactory} from "lib/mento-core/contracts/interfaces/IVirtualPoolFactory.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";

/// @dev Minimal interface for the Broker's auto-generated public mapping getter.
interface IBrokerTradingLimits {
    function tradingLimitsConfig(bytes32 limitId)
        external
        view
        returns (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags);
}

/**
 * @title DeprecateExchangePools
 * @notice Deprecates every exchange flagged `deprecated: true` in the network config.
 *         For each flagged exchange, in order:
 *           1. Deprecate its VirtualPool on the VirtualPoolFactory (if one exists), cutting the
 *              pair out of MentoRouter routing before the underlying exchange disappears.
 *           2. Destroy the exchange on the BiPoolManager.
 *           3. Zero the Broker's trading-limit configs for both assets, which destroyExchange
 *              leaves orphaned and which would otherwise resurrect if the exchangeId were recreated.
 *         Idempotent: completed steps are detected and skipped, so the script can be re-run.
 */
contract DeprecateExchangePools is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    /// @custom:senders migrationOwner, governor
    /// @custom:env {bytes32:optional} exchangeId
    function run() public broadcast {
        // BiPoolManager and VirtualPoolFactory are owned by migrationOwner; the Broker by governance.
        Senders.Sender storage owner = sender("migrationOwner");
        Senders.Sender storage governor = sender("governor");

        // Required if any trading-limit cleanup gets queued on the governor; harmless otherwise
        // (the proposal is only created when the governor queue is non-empty).
        governor.ozGovernor().setTitle("Deprecate Mento v2 exchange pools: clean up orphaned trading limits");
        governor.ozGovernor().setProposalDescription("./mgps/deprecate-v2-pools.md");

        address biPoolManager = lookupProxyOrFail("BiPoolManager");
        address broker = lookupProxyOrFail("Broker");
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

            console.log(string.concat("\n===== Deprecating ", _pairName(asset0, asset1), " ====="));

            _deprecateVirtualPool(owner, asset0, asset1);

            if (!live) {
                console.log("  > Exchange not found on-chain; skipping destroy and limits cleanup");
                continue;
            }

            console.log("  exchangeId:", vm.toString(exchangeId));
            IBiPoolManager(owner.harness(biPoolManager)).destroyExchange(exchangeId, index);
            console.log("  > Destroyed exchange at index", index);

            _zeroTradingLimits(governor, broker, exchangeId, asset0);
            _zeroTradingLimits(governor, broker, exchangeId, asset1);
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
            console.log("  > No VirtualPoolFactory deployed; skipping virtual pool deprecation");
            return;
        }

        address pool = IVirtualPoolFactory(factory).getPool(asset0, asset1);
        if (pool == address(0)) {
            console.log("  > No virtual pool for pair");
            return;
        }

        if (IVirtualPoolFactory(factory).isPoolDeprecated(pool)) {
            console.log("  > Virtual pool already deprecated:", pool);
            return;
        }

        IVirtualPoolFactory(owner.harness(factory)).deprecatePool(pool);
        console.log("  > Deprecated virtual pool:", pool);
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

    /// @dev Step 3: zero the orphaned trading-limit config (keyed exchangeId ^ token) on the Broker.
    function _zeroTradingLimits(Senders.Sender storage governor, address broker, bytes32 exchangeId, address token)
        internal
    {
        bytes32 limitId = exchangeId ^ bytes32(uint256(uint160(token)));
        (,,,,, uint8 flags) = IBrokerTradingLimits(broker).tradingLimitsConfig(limitId);
        if (flags == 0) {
            console.log("  > No trading limits configured for", IERC20Metadata(token).symbol());
            return;
        }

        ITradingLimits.Config memory zeroed;
        IBroker(governor.harness(broker)).configureTradingLimit(exchangeId, token, zeroed);
        console.log("  > Zeroed trading limits for", IERC20Metadata(token).symbol());
    }

    function _pairName(address asset0, address asset1) internal view returns (string memory) {
        return string.concat(IERC20Metadata(asset0).symbol(), "/", IERC20Metadata(asset1).symbol());
    }
}
