// solhint-disable max-line-length, function-max-lines
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {StableTokenV3} from "mento-core/tokens/StableTokenV3.sol";
import {
    CDPLiquidityStrategy
} from "mento-core/liquidityStrategies/CDPLiquidityStrategy.sol";

contract DeployLiquityDependenciesTest is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    Senders.Sender deployer;
    address owner;

    /// @custom:senders deployer
    function run() public broadcast {
        owner = address(123456);
        deployer = sender("deployer");
        _deployDependenciesLocalFork();
    }

    function _deployDependenciesLocalFork() public {
        address[] memory emptyAddressArray = new address[](0);
        uint256[] memory emptyUintArray = new uint256[](0);

        address debtToken = deployer
            .create3("StableTokenV3")
            .setLabel("GBPm")
            .deploy(abi.encode(false));

        IStableTokenV3(debtToken).initialize(
            "GBPm",
            "GBPm",
            owner,
            emptyAddressArray,
            emptyUintArray,
            emptyAddressArray,
            emptyAddressArray,
            emptyAddressArray
        );

        address collateralToken = deployer
            .create3("StableTokenV3")
            .setLabel("USDm")
            .deploy(abi.encode(false));

        IStableTokenV3(collateralToken).initialize(
            "USDm",
            "USDm",
            owner,
            emptyAddressArray,
            emptyUintArray,
            emptyAddressArray,
            emptyAddressArray,
            emptyAddressArray
        );

        address cdpLiquidityStrategy = deployer
            .create3("CDPLiquidityStrategy")
            .setLabel("TestStrategy")
            .deploy(abi.encode(false, 1e6));

        address proxyAdmin = deployer
            .create3("ProxyAdmin")
            .setLabel("TestProxyAdmin")
            .deploy(abi.encode(owner));

        console.log("Test Dependencies deployed to Fork");
        console.log("debtToken: ", debtToken);
        console.log("collateralToken: ", collateralToken);
        console.log("cdpLiquidityStrategy: ", cdpLiquidityStrategy);
        console.log("proxyAdmin: ", proxyAdmin);
        return;
    }
}
