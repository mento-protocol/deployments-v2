// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {Registry} from "lib/treb-sol/src/internal/Registry.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {V3IntegrationBase} from "test/integration/V3IntegrationBase.t.sol";
import {IMentoConfig} from "../../script/config/IMentoConfig.sol";
import {Config} from "../../script/config/Config.sol";
import {MockCELO} from "script/helpers/MockCELO.sol";

contract WeekendSituationTest is V3IntegrationBase {
    address internal constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant AUSD_WHALE = 0x4A4593C5D963473A95f0762Bd6dF4571542AF651;

    function setUp() public override {
        // Replicate base setUp WITHOUT OracleHelper.refreshOracleRates()
        // so we test the real on-chain oracle state.
        forkId = vm.createFork(vm.envString("FORK_URL"));
        vm.selectFork(forkId);

        string memory namespace = vm.envOr("NAMESPACE", string("default"));
        registry = new Registry(namespace, ".treb/registry.json", ".treb/addressbook.json");

        _setDummySenderConfigs();
        config = Config.get();
        vm.selectFork(forkId);
        if (_isCelo()) {
            vm.etch(lookupOrFail("CELO"), type(MockCELO).runtimeCode);
        }

        sortedOracles = lookupProxyOrFail("SortedOracles");
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
    }

    function test_swapDuringTheWeekend() public {
        vm.warp(timestamp_weekend);

        IFPMMFactory fpmmFactory = IFPMMFactory(fpmmFactory);
        address[] memory fpmms = fpmmFactory.deployedFPMMAddresses();

        for (uint256 i = 0; i < fpmms.length; i++) {
            IFPMM fpmm = IFPMM(fpmms[i]);
            bytes4 expectedError = _isCollateralFpmm(fpmm) ? bytes4(0) : IOracleAdapter.FXMarketClosed.selector;
            _swapBothWays(fpmm, expectedError);
        }
    }

    function test_swapDuringAWeekday() public {
        vm.warp(timestamp_weekday);

        IFPMMFactory fpmmFactory = IFPMMFactory(fpmmFactory);
        address[] memory fpmms = fpmmFactory.deployedFPMMAddresses();

        for (uint256 i = 0; i < fpmms.length; i++) {
            IFPMM fpmm = IFPMM(fpmms[i]);
            _swapBothWays(fpmm, bytes4(0));
        }
    }

    function _isCollateralFpmm(IFPMM fpmm) internal view returns (bool) {
        (address token0, address token1) = fpmm.tokens();
        return config.isCollateralAsset(token0) || config.isCollateralAsset(token1);
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

        _dealSelf(address(tokenIn), amountIn);
        tokenIn.transfer(address(fpmm), amountIn);
        fpmm.swap(0, amountOut, address(this), "");
        tokenIn = IERC20Metadata(fpmm.token1());
        amountIn = amountOut;
        amountOut = fpmm.getAmountOut(amountIn, address(tokenIn));
        tokenIn.transfer(address(fpmm), amountIn);
        fpmm.swap(amountOut, 0, address(this), "");
    }

    function _dealSelf(address token, uint256 amount) internal {
        if (token == AUSD) {
            vm.prank(AUSD_WHALE);
            IERC20Metadata(token).transfer(address(this), amount);
            return;
        }
        deal(token, address(this), amount);
    }
}
