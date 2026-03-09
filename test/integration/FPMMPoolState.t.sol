// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";

/**
 * @title FPMMPoolState
 * @notice Verifies each deployed FPMM pool has correct tokens, oracle config,
 *         params, and liquidity.
 */
contract FPMMPoolState is V3IntegrationBase {
    address[] internal pools;

    function setUp() public override {
        super.setUp();
        pools = IFPMMFactory(fpmmFactory).deployedFPMMAddresses();
    }

    // ========== Pool Registration ==========

    function test_pools_exist() public view {
        assertGt(pools.length, 0, "No FPMM pools deployed");
    }

    // ========== Token Sorting ==========

    function test_allPools_tokensSorted() public view {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            address t0 = pool.token0();
            address t1 = pool.token1();
            assertLt(uint160(t0), uint160(t1), string.concat("Tokens not sorted for pool at index ", vm.toString(i)));
        }
    }

    // ========== Oracle Configuration ==========

    function test_allPools_oracleAdapter() public view {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            assertEq(
                address(pool.oracleAdapter()),
                oracleAdapter,
                string.concat("OracleAdapter mismatch on pool at index ", vm.toString(i))
            );
        }
    }

    function test_allPools_referenceRateFeedID_nonZero() public view {
        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            assertNotEq(
                pool.referenceRateFeedID(),
                address(0),
                string.concat("referenceRateFeedID is zero on pool at index ", vm.toString(i))
            );
        }
    }

    // ========== FPMM Params Match Config ==========

    function test_allPools_paramsMatchConfig() public view {
        IMentoConfig.FPMMConfig[] memory fpmmConfigs = config.getFPMMConfigs();

        for (uint256 i = 0; i < pools.length; i++) {
            IFPMM pool = IFPMM(pools[i]);
            address t0 = pool.token0();
            address t1 = pool.token1();

            IFPMM.FPMMParams memory expected = _findFPMMParams(fpmmConfigs, t0, t1);
            string memory idx = vm.toString(i);

            assertEq(pool.lpFee(), expected.lpFee, string.concat("lpFee mismatch on pool ", idx));
            assertEq(pool.protocolFee(), expected.protocolFee, string.concat("protocolFee mismatch on pool ", idx));
            assertEq(
                pool.protocolFeeRecipient(),
                expected.protocolFeeRecipient,
                string.concat("protocolFeeRecipient mismatch on pool ", idx)
            );
            assertEq(pool.feeSetter(), expected.feeSetter, string.concat("feeSetter mismatch on pool ", idx));
            assertEq(
                pool.rebalanceIncentive(),
                expected.rebalanceIncentive,
                string.concat("rebalanceIncentive mismatch on pool ", idx)
            );
            assertEq(
                pool.rebalanceThresholdAbove(),
                expected.rebalanceThresholdAbove,
                string.concat("rebalanceThresholdAbove mismatch on pool ", idx)
            );
            assertEq(
                pool.rebalanceThresholdBelow(),
                expected.rebalanceThresholdBelow,
                string.concat("rebalanceThresholdBelow mismatch on pool ", idx)
            );
        }
    }

    /// @dev Finds the FPMMParams for a token pair from the config array
    function _findFPMMParams(IMentoConfig.FPMMConfig[] memory fpmmConfigs, address t0, address t1)
        internal
        pure
        returns (IFPMM.FPMMParams memory)
    {
        for (uint256 i = 0; i < fpmmConfigs.length; i++) {
            if (
                (fpmmConfigs[i].token0 == t0 && fpmmConfigs[i].token1 == t1)
                    || (fpmmConfigs[i].token0 == t1 && fpmmConfigs[i].token1 == t0)
            ) {
                return fpmmConfigs[i].params;
            }
        }
        revert("FPMMConfig not found for token pair");
    }

    // ========== Reserves and Liquidity ==========

    function test_allPools_nonZeroReserves() public view {
        for (uint256 i = 0; i < pools.length; i++) {
            (uint256 r0, uint256 r1,) = IFPMM(pools[i]).getReserves();
            assertGt(r0, 0, string.concat("reserve0 is zero on pool at index ", vm.toString(i)));
            assertGt(r1, 0, string.concat("reserve1 is zero on pool at index ", vm.toString(i)));
        }
    }

    function test_allPools_nonZeroTotalSupply() public view {
        for (uint256 i = 0; i < pools.length; i++) {
            uint256 supply = IERC20(pools[i]).totalSupply();
            assertGt(supply, 0, string.concat("LP totalSupply is zero on pool at index ", vm.toString(i)));
        }
    }
}
