// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {V3IntegrationBase} from "test/integration/V3IntegrationBase.t.sol";
import {IMentoConfig} from "../../script/config/IMentoConfig.sol";
import {Config} from "../../script/config/Config.sol";
import {MockCELO} from "script/helpers/MockCELO.sol";

contract WeekendSituationTest is V3IntegrationBase {
    address internal constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant AUSD_WHALE = 0x4A4593C5D963473A95f0762Bd6dF4571542AF651;

    function test_swapDuringTheWeekend() public {
        vm.warp(timestamp_weekend);
        _refreshOracleRatesExpectingWeekendReverts();

        address[] memory fpmms = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();

        for (uint256 i = 0; i < fpmms.length; i++) {
            IFPMM fpmm = IFPMM(fpmms[i]);
            _ensurePoolLiquidity(fpmms[i]);
            bytes4 expectedError = _isCollateralFpmm(fpmm) ? bytes4(0) : IOracleAdapter.FXMarketClosed.selector;
            _swapBothWays(fpmm, expectedError);
        }
    }

    function test_swapDuringAWeekday() public {
        vm.warp(timestamp_weekday);
        _refreshOracleRates();

        address[] memory fpmms = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();

        for (uint256 i = 0; i < fpmms.length; i++) {
            _ensurePoolLiquidity(fpmms[i]);
            IFPMM fpmm = IFPMM(fpmms[i]);
            _swapBothWays(fpmm, bytes4(0));
        }
    }

    function _isCollateralFpmm(IFPMM fpmm) internal view returns (bool) {
        (address token0, address token1) = fpmm.tokens();
        return config.isCollateralAsset(token0) || config.isCollateralAsset(token1);
    }

    /// @dev Refreshes oracle rates during the weekend. FX feeds are expected to revert
    ///      (MarketHoursBreaker blocks them); collateral feeds should refresh normally.
    function _refreshOracleRatesExpectingWeekendReverts() internal {
        ISortedOracles so = ISortedOracles(sortedOracles);
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            address rateFeedID = fpmmConfigs[i].referenceRateFeedID;
            (uint256 rate,) = so.medianRate(rateFeedID);
            if (rate == 0) continue;

            address[] memory oracles = so.getOracles(rateFeedID);
            if (oracles.length == 0) continue;

            vm.prank(oracles[0]);
            try so.report(rateFeedID, rate, address(0), address(0)) {}
                catch {
                // FX feeds revert during weekend hours — this is expected
            }
        }
    }

    function _swapBothWays(IFPMM fpmm, bytes4 expectedError) internal {
        IERC20Metadata tokenIn = IERC20Metadata(fpmm.token0());
        uint256 amountIn = 10 ** tokenIn.decimals();
        if (expectedError != bytes4(0)) {
            vm.expectRevert(expectedError);
            fpmm.getAmountOut(amountIn, address(tokenIn));
            return;
        }
        uint256 amountOut = fpmm.getAmountOut(amountIn, address(tokenIn));

        _dealTokens(address(tokenIn), address(this), amountIn);
        tokenIn.transfer(address(fpmm), amountIn);
        fpmm.swap(0, amountOut, address(this), "");
        tokenIn = IERC20Metadata(fpmm.token1());
        amountIn = amountOut;
        amountOut = fpmm.getAmountOut(amountIn, address(tokenIn));
        tokenIn.transfer(address(fpmm), amountIn);
        fpmm.swap(amountOut, 0, address(this), "");
    }
}
