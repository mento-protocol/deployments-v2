// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IBiPoolManager, IPricingModule, FixidityLib} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {ITradingLimits} from "lib/mento-core/contracts/interfaces/ITradingLimits.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev Minimal interface for the Broker's auto-generated public mapping getter.
interface IBrokerTradingLimits {
    function tradingLimitsConfig(bytes32 limitId)
        external
        view
        returns (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags);
}

/**
 * @title ExchangeVerification
 * @notice Verifies that all V2 BiPoolManager exchange configurations match on-chain state.
 *
 *         Uses on-chain exchange IDs as the source of truth (since exchange IDs are
 *         hashed from token symbols at creation time, and symbols have since been renamed).
 *         Matches on-chain pools to config entries by asset addresses and pricing module.
 */
contract ExchangeVerification is V3IntegrationBase {
    address internal biPoolManager;

    function setUp() public override {
        super.setUp();
        if (!_isCelo()) vm.skip(true);
        return;
        biPoolManager = lookupProxyOrFail("BiPoolManager");
    }

    // ========== Pool Assets & Pricing Module ==========

    /// @notice Every on-chain exchange must have a matching config entry with correct assets and pricing module
    function test_allOnChainExchanges_matchConfigAssets() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();
        assertGt(exchangeIds.length, 0, "No on-chain exchanges found");

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);

            assertTrue(found, string.concat(label, " has no matching config entry"));
            assertEq(cfg.pool.asset0, actual.asset0, string.concat(label, " asset0 mismatch"));
            assertEq(cfg.pool.asset1, actual.asset1, string.concat(label, " asset1 mismatch"));
            assertEq(
                address(cfg.pool.pricingModule),
                address(actual.pricingModule),
                string.concat(label, " pricingModule mismatch")
            );
        }
    }

    // ========== Exchange Config (spread, referenceRateFeedID, etc.) ==========

    /// @notice Verify spread for every on-chain exchange
    function test_allOnChainExchanges_spread() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertEq(actual.config.spread.value, cfg.pool.config.spread.value, string.concat(label, " spread mismatch"));
        }
    }

    /// @notice Verify referenceRateFeedID for every on-chain exchange
    function test_allOnChainExchanges_referenceRateFeedID() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertEq(
                actual.config.referenceRateFeedID,
                cfg.pool.config.referenceRateFeedID,
                string.concat(label, " referenceRateFeedID mismatch")
            );
        }
    }

    /// @notice Verify referenceRateResetFrequency for every on-chain exchange
    function test_allOnChainExchanges_referenceRateResetFrequency() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertEq(
                actual.config.referenceRateResetFrequency,
                cfg.pool.config.referenceRateResetFrequency,
                string.concat(label, " referenceRateResetFrequency mismatch")
            );
        }
    }

    /// @notice Verify minimumReports for every on-chain exchange
    function test_allOnChainExchanges_minimumReports() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertEq(
                actual.config.minimumReports,
                cfg.pool.config.minimumReports,
                string.concat(label, " minimumReports mismatch")
            );
        }
    }

    /// @notice Verify stablePoolResetSize for every on-chain exchange
    function test_allOnChainExchanges_stablePoolResetSize() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertEq(
                actual.config.stablePoolResetSize,
                cfg.pool.config.stablePoolResetSize,
                string.concat(label, " stablePoolResetSize mismatch")
            );
        }
    }

    // ========== Full Exchange Config (combined assertion) ==========

    /// @notice Verify ALL exchange config fields in a single pass
    function test_allOnChainExchanges_fullConfig() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();
        assertGt(exchangeIds.length, 0, "No on-chain exchanges found");

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));

            string memory label = _exchangeLabel(i, actual.asset0, actual.asset1);
            assertTrue(found, string.concat(label, " has no matching config entry"));

            assertEq(actual.asset0, cfg.pool.asset0, string.concat(label, " asset0 mismatch"));
            assertEq(actual.asset1, cfg.pool.asset1, string.concat(label, " asset1 mismatch"));
            assertEq(
                address(actual.pricingModule),
                address(cfg.pool.pricingModule),
                string.concat(label, " pricingModule mismatch")
            );
            assertEq(actual.config.spread.value, cfg.pool.config.spread.value, string.concat(label, " spread mismatch"));
            assertEq(
                actual.config.referenceRateFeedID,
                cfg.pool.config.referenceRateFeedID,
                string.concat(label, " referenceRateFeedID mismatch")
            );
            assertEq(
                actual.config.referenceRateResetFrequency,
                cfg.pool.config.referenceRateResetFrequency,
                string.concat(label, " referenceRateResetFrequency mismatch")
            );
            assertEq(
                actual.config.minimumReports,
                cfg.pool.config.minimumReports,
                string.concat(label, " minimumReports mismatch")
            );
            assertEq(
                actual.config.stablePoolResetSize,
                cfg.pool.config.stablePoolResetSize,
                string.concat(label, " stablePoolResetSize mismatch")
            );
        }
    }

    // ========== Trading Limits ==========

    /// @notice Verify trading limits for asset0 of every on-chain exchange
    function test_allOnChainExchanges_tradingLimits_asset0() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            bytes32 limitId = exchangeIds[i] ^ bytes32(uint256(uint160(actual.asset0)));
            ITradingLimits.Config memory actualLimits = _getTradingLimitsConfig(limitId);

            string memory label =
                string.concat(_exchangeLabel(i, actual.asset0, actual.asset1), " asset0 trading limits");
            _assertTradingLimitsEqual(actualLimits, cfg.tradingLimits.asset0, label);
        }
    }

    /// @notice Verify trading limits for asset1 of every on-chain exchange
    function test_allOnChainExchanges_tradingLimits_asset1() public view {
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory actual = IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory cfg, bool found) =
                config.getExchangeConfig(actual.asset0, actual.asset1, address(actual.pricingModule));
            if (!found) continue;

            bytes32 limitId = exchangeIds[i] ^ bytes32(uint256(uint160(actual.asset1)));
            ITradingLimits.Config memory actualLimits = _getTradingLimitsConfig(limitId);

            string memory label =
                string.concat(_exchangeLabel(i, actual.asset0, actual.asset1), " asset1 trading limits");
            _assertTradingLimitsEqual(actualLimits, cfg.tradingLimits.asset1, label);
        }
    }

    // ========== Bidirectional Consistency ==========

    /// @notice Every config exchange must have a matching on-chain exchange
    function test_allConfigExchanges_haveOnChainEntry() public view {
        IMentoConfig.ExchangeConfig[] memory exchanges = config.getExchanges();
        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager).getExchangeIds();

        for (uint256 c = 0; c < exchanges.length; c++) {
            IBiPoolManager.PoolExchange memory expected = exchanges[c].pool;
            bool found = false;

            for (uint256 i = 0; i < exchangeIds.length; i++) {
                IBiPoolManager.PoolExchange memory onChain =
                    IBiPoolManager(biPoolManager).getPoolExchange(exchangeIds[i]);

                bool assetsMatch = (onChain.asset0 == expected.asset0 && onChain.asset1 == expected.asset1)
                    || (onChain.asset0 == expected.asset1 && onChain.asset1 == expected.asset0);

                if (assetsMatch && address(onChain.pricingModule) == address(expected.pricingModule)) {
                    found = true;
                    break;
                }
            }

            assertTrue(found, string.concat(_exchangeLabel(c, expected.asset0, expected.asset1), " not found on-chain"));
        }
    }

    // ========== Internal Helpers ==========

    /// @dev Queries the Broker's tradingLimitsConfig public mapping getter and returns a Config struct.
    function _getTradingLimitsConfig(bytes32 limitId) internal view returns (ITradingLimits.Config memory cfg) {
        (cfg.timestep0, cfg.timestep1, cfg.limit0, cfg.limit1, cfg.limitGlobal, cfg.flags) =
            IBrokerTradingLimits(broker).tradingLimitsConfig(limitId);
    }

    /// @dev Asserts all fields of two ITradingLimits.Config structs are equal.
    function _assertTradingLimitsEqual(
        ITradingLimits.Config memory actual,
        ITradingLimits.Config memory expected,
        string memory label
    ) internal pure {
        assertEq(actual.timestep0, expected.timestep0, string.concat(label, " timestep0 mismatch"));
        assertEq(actual.timestep1, expected.timestep1, string.concat(label, " timestep1 mismatch"));
        assertEq(actual.limit0, expected.limit0, string.concat(label, " limit0 mismatch"));
        assertEq(actual.limit1, expected.limit1, string.concat(label, " limit1 mismatch"));
        assertEq(actual.limitGlobal, expected.limitGlobal, string.concat(label, " limitGlobal mismatch"));
        assertEq(actual.flags, expected.flags, string.concat(label, " flags mismatch"));
    }

    /// @dev Builds a human-readable label for assertion messages, e.g. "Exchange[0] (USDm/CELO)"
    function _exchangeLabel(uint256 index, address asset0, address asset1) internal view returns (string memory) {
        string memory symbol0 = _safeSymbol(asset0);
        string memory symbol1 = _safeSymbol(asset1);
        return string.concat("Exchange[", vm.toString(index), "] (", symbol0, "/", symbol1, ")");
    }

    /// @dev Attempts to read the ERC20 symbol; falls back to the hex address on failure.
    function _safeSymbol(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return vm.toString(token);
        }
    }
}
