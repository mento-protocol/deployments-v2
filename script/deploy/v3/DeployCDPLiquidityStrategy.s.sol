// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {ICDPLiquidityStrategy} from "mento-core/interfaces/ICDPLiquidityStrategy.sol";

contract DeployCDPLiquidityStrategy is
    TrebScript,
    AddressbookHelper,
    ProxyHelper,
    PostChecksHelper
{
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address multisig;
    address cdpLiquidityStrategyImpl;
    address cdpLiquidityStrategy;
    IMentoConfig config;

    string constant label = "v3.0.0";

    function setUp() public {
        multisig = lookupAddressbook("MigrationMultisig");
        config = Config.get();
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        cdpLiquidityStrategyImpl = deployer
            .create3("CDPLiquidityStrategy")
            .setLabel(label)
            .deploy(
                abi.encode(true, config.getCDPRedemptionShortfallTolerance())
            );

        cdpLiquidityStrategy = deployProxy(
            deployer,
            "CDPLiquidityStrategy",
            cdpLiquidityStrategyImpl,
            abi.encodeWithSelector(
                ICDPLiquidityStrategy.initialize.selector,
                multisig
            )
        );
        postChecks();
    }

    function postChecks() internal view {
        verifyProxyImpl(
            "CDPLiquidityStrategy",
            cdpLiquidityStrategy,
            cdpLiquidityStrategyImpl
        );
        verifyOwnership("CDPLiquidityStrategy", cdpLiquidityStrategy, multisig);
    }
}
