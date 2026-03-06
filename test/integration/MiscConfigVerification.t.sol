// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase, IPoolConfigReader} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IReserve} from "mento-core/interfaces/IReserve.sol";
import {IReserveV2} from "mento-core/interfaces/IReserveV2.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {LatestTroveData} from "bold/src/Types/LatestTroveData.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";

/// @dev Minimal interface for reading the CDPLiquidityStrategy immutable
interface ICDPLiquidityStrategyView {
    function REDEMPTION_SHORTFALL_TOLERANCE() external view returns (uint256);
}

/**
 * @title MiscConfigVerification
 * @notice Verifies remaining config blind spots against on-chain state:
 *         - FPMM: invertRateFeed and proxy implementation per pool
 *         - TokenConfig: on-chain symbol and name match config
 *         - CollateralAssets: config addresses are registered in Reserve and ReserveV2
 *         - CDPMigration: collateralizationRatio and redemptionShortfallTolerance
 */
contract MiscConfigVerification is V3IntegrationBase {
    address[] internal pools;

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
    }

    // ================================================================
    // ========== FPMM: invertRateFeed matches config ==================
    // ================================================================

    /// @notice Verify each deployed FPMM pool's invertRateFeed flag matches config
    function test_allPools_invertRateFeed_matchesConfig() public view {
        IMentoConfig.FPMMConfig[] memory cfgs = config.getFPMMConfigs();
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            address t0 = pool.token0();
            address t1 = pool.token1();

            IMentoConfig.FPMMConfig memory cfg = _findFPMMConfig(cfgs, t0, t1);
            string memory idx = vm.toString(i);

            assertEq(
                pool.invertRateFeed(),
                cfg.invertRateFeed,
                string.concat("invertRateFeed mismatch on pool at index ", idx)
            );
        }
    }

    // ================================================================
    // ========== FPMM: proxy implementation matches config ============
    // ================================================================

    /// @notice Verify each deployed FPMM pool proxy's implementation matches config
    function test_allPools_fpmmImplementation_matchesConfig() public view {
        IMentoConfig.FPMMConfig[] memory cfgs = config.getFPMMConfigs();
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            address t0 = pool.token0();
            address t1 = pool.token1();

            IMentoConfig.FPMMConfig memory cfg = _findFPMMConfig(cfgs, t0, t1);
            string memory idx = vm.toString(i);

            address actualImpl = getProxyImplementation(pools[i]);
            assertEq(
                actualImpl, cfg.fpmmImplementation, string.concat("fpmmImplementation mismatch on pool at index ", idx)
            );
        }
    }

    // ================================================================
    // ========== TokenConfig: symbol matches on-chain ==================
    // ================================================================

    /// @notice Verify on-chain token symbol matches config for each stable token
    function test_tokenConfigs_symbol_matchesOnChain() public view {
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = lookupProxyOrFail(tokens[i].symbol);
            string memory actualSymbol = IERC20Metadata(tokenAddr).symbol();
            string memory idx = vm.toString(i);

            assertEq(
                keccak256(abi.encodePacked(actualSymbol)),
                keccak256(abi.encodePacked(tokens[i].symbol)),
                string.concat(
                    "Token symbol mismatch at index ", idx, ": on-chain=", actualSymbol, " config=", tokens[i].symbol
                )
            );
        }
    }

    // ================================================================
    // ========== TokenConfig: name matches on-chain ====================
    // ================================================================

    /// @notice Verify on-chain token name matches config for each stable token
    function test_tokenConfigs_name_matchesOnChain() public view {
        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = lookupProxyOrFail(tokens[i].symbol);
            string memory actualName = IERC20Metadata(tokenAddr).name();
            string memory idx = vm.toString(i);

            assertEq(
                keccak256(abi.encodePacked(actualName)),
                keccak256(abi.encodePacked(tokens[i].name)),
                string.concat(
                    "Token name mismatch at index ", idx, ": on-chain=", actualName, " config=", tokens[i].name
                )
            );
        }
    }

    // ================================================================
    // ========== CollateralAssets: registered in Reserve ===============
    // ================================================================

    /// @notice Verify each collateral asset from config is registered in Reserve (V1)
    function test_collateralAssets_registeredInReserve() public {
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        address reserve = lookupProxyOrFail("Reserve");
        address[] memory collateralAssets = config.getCollateralAssets();

        for (uint256 i = 0; i < collateralAssets.length; i++) {
            assertTrue(
                IReserve(reserve).isCollateralAsset(collateralAssets[i]),
                string.concat("Collateral asset not registered in Reserve: ", vm.toString(collateralAssets[i]))
            );
        }
    }

    /// @notice Verify each ReserveV2 collateral asset from config is registered in ReserveV2
    function test_collateralAssets_registeredInReserveV2() public view {
        address[] memory collateralAssets = config.getReserveV2CollateralAssets();

        for (uint256 i = 0; i < collateralAssets.length; i++) {
            assertTrue(
                IReserveV2(reserveV2).isCollateralAsset(collateralAssets[i]),
                string.concat("Collateral asset not registered in ReserveV2: ", vm.toString(collateralAssets[i]))
            );
        }
    }

    // ================================================================
    // ========== CDPMigration: collateralizationRatio ==================
    // ================================================================

    /// @notice Verify each CDP pool's reserve trove ICR is at least the configured collateralizationRatio.
    ///         The collateralizationRatio is not stored on-chain directly; it is used as a target when
    ///         creating the reserve trove. We verify the resulting trove's ICR meets or exceeds the target.
    function test_cdpPools_collateralizationRatio_met() public {
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        address[] memory cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();

        for (uint256 i = 0; i < cdpPools.length; i++) {
            // Derive the debt token symbol to look up CDPMigrationConfig
            address debtToken = _getDebtToken(cdpPools[i]);
            string memory symbol = IERC20Metadata(debtToken).symbol();
            IMentoConfig.CDPMigrationConfig memory cdpCfg = config.getCDPMigrationConfig(symbol);

            // Get the trove manager and find the reserve trove
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);
            uint256 troveId = _findReserveTrove(troveManagerAddr);

            // Fetch the current price from the Liquity price feed
            address priceFeedAddr = _getPriceFeed(troveManagerAddr);
            uint256 price = IPriceFeed(priceFeedAddr).fetchPrice();

            // getCurrentICR returns the trove's ICR as an 18-decimal fixed-point number
            uint256 currentICR = ITroveManager(troveManagerAddr).getCurrentICR(troveId, price);

            string memory idx = vm.toString(i);

            // Allow 5% tolerance for price drift
            uint256 minICR = (cdpCfg.collateralizationRatio * 95) / 100;
            assertGe(
                currentICR,
                minICR,
                string.concat(
                    "Reserve trove ICR more than 5% below configured collateralizationRatio for CDP pool at index ",
                    idx,
                    " (ICR=",
                    vm.toString(currentICR),
                    ", target=",
                    vm.toString(cdpCfg.collateralizationRatio),
                    ")"
                )
            );
        }
    }

    // ================================================================
    // ========== CDPMigration: redemptionShortfallTolerance ============
    // ================================================================

    /// @notice Verify the CDPLiquidityStrategy's REDEMPTION_SHORTFALL_TOLERANCE matches config
    function test_cdpLiquidityStrategy_redemptionShortfallTolerance_matchesConfig() public {
        if (!_isCelo()) {
            vm.skip(true);
            return;
        }
        uint256 expected = config.getCDPRedemptionShortfallTolerance();
        uint256 actual = ICDPLiquidityStrategyView(cdpLiquidityStrategy).REDEMPTION_SHORTFALL_TOLERANCE();

        assertEq(actual, expected, "CDPLiquidityStrategy.REDEMPTION_SHORTFALL_TOLERANCE does not match config");
    }

    // ================================================================
    // ========== Internal Helpers ======================================
    // ================================================================

    /// @dev Finds the FPMMConfig for a token pair from the config array
    function _findFPMMConfig(IMentoConfig.FPMMConfig[] memory cfgs, address t0, address t1)
        internal
        pure
        returns (IMentoConfig.FPMMConfig memory)
    {
        for (uint256 i = 0; i < cfgs.length; i++) {
            if ((cfgs[i].token0 == t0 && cfgs[i].token1 == t1) || (cfgs[i].token0 == t1 && cfgs[i].token1 == t0)) {
                return cfgs[i];
            }
        }
        revert("FPMMConfig not found for token pair");
    }
}
