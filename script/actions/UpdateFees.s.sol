// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IExchangeProvider} from "lib/mento-core/contracts/interfaces/IExchangeProvider.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FixidityLib} from "@celo/common/FixidityLib.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {ConfigHelper} from "../helpers/ConfigHelper.sol";

contract UpdateFees is TrebScript, ProxyHelper, ConfigHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;

    /// @custom:senders migrationOwner
    function run() public virtual broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        _updateV2Spreads(owner);
        _updateV3Fees(owner);
        _verify();
    }

    function _updateV2Spreads(Senders.Sender storage owner) internal {
        address biPoolManagerAddy = lookupProxyOrFail("BiPoolManager");
        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManagerAddy);
        IBiPoolManager biPoolManager = IBiPoolManager(owner.harness(biPoolManagerAddy));

        IMentoConfig.ExchangeConfig[] memory configExchanges = config.getExchanges();
        IExchangeProvider.Exchange[] memory onChainExchanges = biPoolManagerRead.getExchanges();

        console.log("\n===== Checking v2 BiPoolManager spreads =====");

        bool anyUpdated = false;

        for (uint256 i = 0; i < onChainExchanges.length; i++) {
            bytes32 exchangeId = onChainExchanges[i].exchangeId;
            IBiPoolManager.PoolExchange memory onChainPool = biPoolManagerRead.getPoolExchange(exchangeId);

            string memory symbol0 = IERC20Metadata(onChainPool.asset0).symbol();
            string memory symbol1 = IERC20Metadata(onChainPool.asset1).symbol();

            (IMentoConfig.ExchangeConfig memory configExchange, bool found) =
                _findConfigExchange(configExchanges, onChainPool.asset0, onChainPool.asset1);

            if (!found) {
                console.log("  Skipping %s/%s (no matching config found)", symbol0, symbol1);
                continue;
            }

            uint256 configSpread = configExchange.pool.config.spread.value;
            uint256 onChainSpread = onChainPool.config.spread.value;

            if (configSpread != onChainSpread) {
                console.log("  Updating spread for %s/%s:", symbol0, symbol1);
                console.log("    exchangeId:", uint256(exchangeId));
                console.log("    old spread:", onChainSpread);
                console.log("    new spread:", configSpread);

                biPoolManager.setSpread(exchangeId, configSpread);
                anyUpdated = true;
            } else {
                console.log("  Spread unchanged for %s/%s", symbol0, symbol1);
            }
        }

        if (!anyUpdated) {
            console.log("  No v2 exchanges need updating");
        }
    }

    function _updateV3Fees(Senders.Sender storage owner) internal {
        address factoryAddy = lookupProxyOrFail("FPMMFactory");
        IFPMMFactory factory = IFPMMFactory(factoryAddy);

        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        console.log("\n===== Checking v3 FPMM fees =====");

        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            IMentoConfig.FPMMConfig memory cfg = fpmmConfigs[i];
            address fpmmProxy = factory.getPool(cfg.token0, cfg.token1);

            if (fpmmProxy == address(0)) {
                revert(
                    string.concat(
                        "  Reverting: FPMM (",
                        IERC20Metadata(cfg.token0).symbol(),
                        "/",
                        IERC20Metadata(cfg.token1).symbol(),
                        ") not deployed on-chain"
                    )
                );
            }

            IFPMM fpmm = IFPMM(fpmmProxy);
            string memory symbol0 = IERC20Metadata(cfg.token0).symbol();
            string memory symbol1 = IERC20Metadata(cfg.token1).symbol();

            bool updated = false;

            uint256 onChainLpFee = fpmm.lpFee();
            if (onChainLpFee != cfg.params.lpFee) {
                IFPMM(owner.harness(fpmmProxy)).setLPFee(cfg.params.lpFee);
                console.log("  Updated lpFee for %s/%s:", symbol0, symbol1);
                console.log("    old lpFee:", onChainLpFee);
                console.log("    new lpFee:", cfg.params.lpFee);
                updated = true;
            }

            uint256 onChainProtocolFee = fpmm.protocolFee();
            if (onChainProtocolFee != cfg.params.protocolFee) {
                IFPMM(owner.harness(fpmmProxy)).setProtocolFee(cfg.params.protocolFee);
                console.log("  Updated protocolFee for %s/%s:", symbol0, symbol1);
                console.log("    old protocolFee:", onChainProtocolFee);
                console.log("    new protocolFee:", cfg.params.protocolFee);
                updated = true;
            }

            if (!updated) {
                console.log("  Fees unchanged for %s/%s", symbol0, symbol1);
            }
        }
    }

    // ========== Verification ==========

    function _verify() internal view {
        console.log("\n===== Verification: current on-chain state =====");

        // Verify v2 spreads
        address biPoolManagerAddy = lookupProxyOrFail("BiPoolManager");
        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManagerAddy);
        IExchangeProvider.Exchange[] memory onChainExchanges = biPoolManagerRead.getExchanges();
        IMentoConfig.ExchangeConfig[] memory configExchanges = config.getExchanges();

        console.log("\n  -- v2 BiPoolManager exchanges --");
        for (uint256 i = 0; i < onChainExchanges.length; i++) {
            bytes32 exchangeId = onChainExchanges[i].exchangeId;
            IBiPoolManager.PoolExchange memory pool = biPoolManagerRead.getPoolExchange(exchangeId);
            string memory symbol0 = IERC20Metadata(pool.asset0).symbol();
            string memory symbol1 = IERC20Metadata(pool.asset1).symbol();

            (IMentoConfig.ExchangeConfig memory configExchange, bool found) =
                _findConfigExchange(configExchanges, pool.asset0, pool.asset1);

            console.log("  %s/%s:", symbol0, symbol1);
            console.log("    on-chain spread:", pool.config.spread.value);
            if (found) {
                console.log("    config spread:  ", configExchange.pool.config.spread.value);
                require(
                    pool.config.spread.value == configExchange.pool.config.spread.value,
                    string.concat("Verify: spread mismatch for ", symbol0, "/", symbol1)
                );
            }
        }

        // Verify v3 FPMM fees
        address factoryAddy = lookupProxyOrFail("FPMMFactory");
        IFPMMFactory factory = IFPMMFactory(factoryAddy);
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        console.log("\n  -- v3 FPMM pools --");
        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            IMentoConfig.FPMMConfig memory cfg = fpmmConfigs[i];
            address fpmmProxy = factory.getPool(cfg.token0, cfg.token1);
            if (fpmmProxy == address(0)) continue;

            IFPMM fpmm = IFPMM(fpmmProxy);
            string memory symbol0 = IERC20Metadata(cfg.token0).symbol();
            string memory symbol1 = IERC20Metadata(cfg.token1).symbol();

            console.log("  %s/%s:", symbol0, symbol1);
            console.log("    on-chain lpFee:", fpmm.lpFee());
            console.log("    config lpFee:  ", cfg.params.lpFee);
            console.log("    on-chain protocolFee:", fpmm.protocolFee());
            console.log("    config protocolFee:  ", cfg.params.protocolFee);

            require(
                fpmm.lpFee() == cfg.params.lpFee, string.concat("Verify: lpFee mismatch for ", symbol0, "/", symbol1)
            );
            require(
                fpmm.protocolFee() == cfg.params.protocolFee,
                string.concat("Verify: protocolFee mismatch for ", symbol0, "/", symbol1)
            );
        }

        console.log("\n  All fees verified successfully");
    }

    // ========== Helpers ==========

    function _findConfigExchange(IMentoConfig.ExchangeConfig[] memory configExchanges, address asset0, address asset1)
        internal
        pure
        returns (IMentoConfig.ExchangeConfig memory, bool)
    {
        for (uint256 i = 0; i < configExchanges.length; i++) {
            if (configExchanges[i].pool.asset0 == asset0 && configExchanges[i].pool.asset1 == asset1) {
                return (configExchanges[i], true);
            }
        }
        IMentoConfig.ExchangeConfig memory empty;
        return (empty, false);
    }

}
