// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";

/**
 * @title StableTokenRoles
 * @notice Tests stable token minting and burning roles for CDP-migrated tokens.
 *         Verifies that authorized Liquity contracts can mint/burn, that Broker is rejected,
 *         and that StabilityPool operator can do direct transfers without approval.
 */
contract StableTokenRoles is V3IntegrationBase {
    address[] internal cdpPools;

    function setUp() public override {
        super.setUp();
        cdpPools = ICDPLiquidityStrategy(cdpLiquidityStrategy).getPools();
        require(cdpPools.length > 0, "No CDP pools found");
    }

    // ========== Minting: BorrowerOperations can mint ==========

    /// @notice BorrowerOperations should be able to mint CDP debt tokens
    function test_cdpDebtToken_borrowerOps_canMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (address borrowerOps,,,) = _getLiquityContracts(cdpPools[i]);
            address recipient = makeAddr("mintRecipient");

            uint256 mintAmount = 1e18;
            uint256 balBefore = IStableTokenV3(debtToken).balanceOf(recipient);

            vm.prank(borrowerOps);
            IStableTokenV3(debtToken).mint(recipient, mintAmount);

            uint256 balAfter = IStableTokenV3(debtToken).balanceOf(recipient);
            assertEq(
                balAfter - balBefore,
                mintAmount,
                string.concat("BorrowerOps mint failed for pool at index ", vm.toString(i))
            );
        }
    }

    // ========== Minting: Random address cannot mint ==========

    /// @notice A random non-authorized address should NOT be able to mint
    function test_cdpDebtToken_randomAddress_cannotMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            address randomUser = makeAddr("randomMinter");

            vm.prank(randomUser);
            vm.expectRevert();
            IStableTokenV3(debtToken).mint(randomUser, 1e18);
        }
    }

    // ========== Burning: Authorized burners can burn ==========

    /// @notice CollateralRegistry should be able to burn CDP debt tokens
    function test_cdpDebtToken_collateralRegistry_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            ICDPLiquidityStrategy.CDPConfig memory cdpConfig =
                ICDPLiquidityStrategy(cdpLiquidityStrategy).getCDPConfig(cdpPools[i]);

            uint256 burnAmount = 1e18;
            deal(debtToken, cdpConfig.collateralRegistry, burnAmount);

            vm.prank(cdpConfig.collateralRegistry);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice BorrowerOperations should be able to burn CDP debt tokens
    function test_cdpDebtToken_borrowerOps_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (address borrowerOps,,,) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            deal(debtToken, borrowerOps, burnAmount);

            vm.prank(borrowerOps);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice TroveManager should be able to burn CDP debt tokens
    function test_cdpDebtToken_troveManager_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,, address troveManagerAddr,) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            deal(debtToken, troveManagerAddr, burnAmount);

            vm.prank(troveManagerAddr);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    /// @notice StabilityPool should be able to burn CDP debt tokens
    function test_cdpDebtToken_stabilityPool_canBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            uint256 burnAmount = 1e18;
            deal(debtToken, stabilityPoolAddr, burnAmount);

            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).burn(burnAmount);
        }
    }

    // ========== Broker cannot mint/burn on CDP-migrated tokens ==========

    /// @notice Broker should NOT be able to mint CDP debt tokens
    function test_cdpDebtToken_broker_cannotMint() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);

            vm.prank(broker);
            vm.expectRevert();
            IStableTokenV3(debtToken).mint(broker, 1e18);
        }
    }

    /// @notice Broker should NOT be able to burn CDP debt tokens
    function test_cdpDebtToken_broker_cannotBurn() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);

            deal(debtToken, broker, 1e18);

            vm.prank(broker);
            vm.expectRevert();
            IStableTokenV3(debtToken).burn(1e18);
        }
    }

    // ========== StabilityPool operator can transfer without approval ==========

    /// @notice StabilityPool as operator can call sendToPool (direct transfer without approval)
    function test_cdpDebtToken_stabilityPool_canSendToPool() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            address sender = makeAddr("tokenHolder");
            uint256 amount = 1e18;
            deal(debtToken, sender, amount);

            uint256 senderBalBefore = IStableTokenV3(debtToken).balanceOf(sender);
            uint256 poolBalBefore = IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr);

            // StabilityPool as operator can transfer from sender to pool without approval
            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).sendToPool(sender, stabilityPoolAddr, amount);

            assertEq(
                IStableTokenV3(debtToken).balanceOf(sender),
                senderBalBefore - amount,
                string.concat("sendToPool: sender balance not decreased for pool at index ", vm.toString(i))
            );
            assertEq(
                IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr),
                poolBalBefore + amount,
                string.concat("sendToPool: pool balance not increased for pool at index ", vm.toString(i))
            );
        }
    }

    /// @notice StabilityPool as operator can call returnFromPool (direct transfer without approval)
    function test_cdpDebtToken_stabilityPool_canReturnFromPool() public {
        for (uint256 i = 0; i < cdpPools.length; i++) {
            address debtToken = _getDebtToken(cdpPools[i]);
            (,,, address stabilityPoolAddr) = _getLiquityContracts(cdpPools[i]);

            address receiver = makeAddr("tokenReceiver");
            uint256 amount = 1e18;
            deal(debtToken, stabilityPoolAddr, amount);

            uint256 poolBalBefore = IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr);
            uint256 receiverBalBefore = IStableTokenV3(debtToken).balanceOf(receiver);

            // StabilityPool as operator can transfer from pool to receiver without approval
            vm.prank(stabilityPoolAddr);
            IStableTokenV3(debtToken).returnFromPool(stabilityPoolAddr, receiver, amount);

            assertEq(
                IStableTokenV3(debtToken).balanceOf(stabilityPoolAddr),
                poolBalBefore - amount,
                string.concat("returnFromPool: pool balance not decreased for pool at index ", vm.toString(i))
            );
            assertEq(
                IStableTokenV3(debtToken).balanceOf(receiver),
                receiverBalBefore + amount,
                string.concat("returnFromPool: receiver balance not increased for pool at index ", vm.toString(i))
            );
        }
    }

}
