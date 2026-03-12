// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {IOpenLiquidityStrategy} from "mento-core/interfaces/IOpenLiquidityStrategy.sol";

contract DeployOpenLiquidityStrategy is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address openLiquidityStrategyImpl;
    address openLiquidityStrategy;
    IMentoConfig config;
    Senders.Sender deployer;
    Senders.Sender owner;

    string constant label = "v3.0.1";

    function setUp() public {
        config = Config.get();
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        deployer = sender("deployer");
        owner = sender("migrationOwner");

        openLiquidityStrategyImpl = deployer.create3("OpenLiquidityStrategy").setLabel(label).deploy(abi.encode(true));

        openLiquidityStrategy = deployProxy(
            deployer,
            "OpenLiquidityStrategy",
            openLiquidityStrategyImpl,
            abi.encodeWithSelector(IOpenLiquidityStrategy.initialize.selector, owner.account)
        );
        postChecks();
    }

    function postChecks() internal view {
        verifyProxyImpl("OpenLiquidityStrategy", openLiquidityStrategy, openLiquidityStrategyImpl);
        verifyOwnership("OpenLiquidityStrategy", openLiquidityStrategy, owner.account);
    }
}
