// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";

contract DeployCDPLiquidityStrategy is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address cdpLiquidityStrategyImpl;
    address cdpLiquidityStrategy;
    IMentoConfig config;
    Senders.Sender deployer;
    Senders.Sender owner;

    string constant label = "v3.0.0";

    function setUp() public {
        config = Config.get();
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        deployer = sender("deployer");
        owner = sender("migrationOwner");

        require(config.getCDPRedemptionShortfallTolerance() > 0, "redemption shortfall tolerance not set");

        cdpLiquidityStrategyImpl = deployer.create3("CDPLiquidityStrategy").setLabel(label)
            .deploy(abi.encode(true, config.getCDPRedemptionShortfallTolerance()));

        cdpLiquidityStrategy = deployProxy(
            deployer,
            "CDPLiquidityStrategy",
            cdpLiquidityStrategyImpl,
            abi.encodeWithSelector(ICDPLiquidityStrategy.initialize.selector, owner.account)
        );
        postChecks();
    }

    function postChecks() internal view {
        verifyProxyImpl("CDPLiquidityStrategy", cdpLiquidityStrategy, cdpLiquidityStrategyImpl);
        verifyOwnership("CDPLiquidityStrategy", cdpLiquidityStrategy, owner.account);
    }
}
