// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {StableTokenV3} from "mento-core/tokens/StableTokenV3.sol";
import {console2 as console} from "forge-std/console2.sol";

contract DeployStableTokenV3 is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address stableTokenV3Impl;
    address stableTokenV3;

    string label = "v3.0.0";

    function setUp() public {}

    /// @custom:senders deployer
    function run() public broadcast {
        setUp();

        Senders.Sender storage deployer = sender("deployer");
        address accnt = deployer.account;
        console.log("Deployer account:", accnt);

        // Deploy implementation with initializers disabled
        stableTokenV3Impl = deployer
            .create3("StableTokenV3")
            .setLabel(label)
            .deploy(abi.encode(true));

        // Deploy proxy with initialization
        // TODO: Set token name, symbol, minters, burners, and operators as needed
        address[] memory initialBalanceAddresses = new address[](1);
        initialBalanceAddresses[0] = accnt;
        uint256[] memory initialBalanceValues = new uint256[](1);
        initialBalanceValues[0] = 1_000_000e18;
        address[] memory minters = new address[](1);
        minters[0] = accnt;
        address[] memory burners = new address[](0);
        address[] memory operators = new address[](0);

        stableTokenV3 = deployProxy(
            deployer,
            "StableTokenV3",
            stableTokenV3Impl,
            abi.encodeWithSelector(
                IStableTokenV3.initialize.selector,
                "Stable Token Test USD v3",
                "testUSDv3",
                accnt,
                initialBalanceAddresses,
                initialBalanceValues,
                minters,
                burners,
                operators
            )
        );

        require(StableTokenV3(stableTokenV3).isMinter(accnt), "Deployer is not a minter");
        require(StableTokenV3(stableTokenV3).balanceOf(accnt) == 1_000_000e18, "Deployer does not have the correct balance");

        // postChecks();
    }

    function postChecks() internal view {
        // Proxy Implementation Check
        // verifyProxyImpl(
        //     "StableTokenV3",
        //     stableTokenV3,
        //     stableTokenV3Impl
        // );

        // // Proxy Admin Check
        // verifyProxyAdmin("StableTokenV3", stableTokenV3, multisig);

        // // Ownership Check
        // verifyOwnership("StableTokenV3", stableTokenV3, multisig);

        // // Implementation Initializer Protection
        // verifyInitDisabled("StableTokenV3Impl", stableTokenV3Impl);
    }
}
