// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {addresses} from "lib/mento-std/src/Array.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {ProxyHelper, ProxyType} from "script/helpers/ProxyHelper.sol";

contract DeployTimelockController is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        config = Config.get();
        IMentoConfig.GovernanceConfig memory govCfg = config.getGovernanceConfig();

        Senders.Sender storage deployer = sender("deployer");
        address mentoGovernor = predictProxy(ProxyType.OZTUP, deployer, "MentoGovernor");

        address implementation = deployer.create3("TimelockController").setLabel("v2.6.5").deploy(abi.encode(true));

        address[] memory proposers = addresses(mentoGovernor); // only Governor can propose
        address[] memory executors = addresses(address(0)); // anybody can execute

        deployProxy(
            ProxyType.OZTUP,
            deployer,
            "TimelockController",
            implementation,
            abi.encodeWithSignature(
                "__MentoTimelockController_init(uint256,address[],address[],address,address)",
                govCfg.timelockDelay, /// @param minDelay The minimum delay before a proposal can be executed.
                proposers, ///            @param proposers List of addresses that are allowed to queue AND cancel operations.
                executors, ///            @param executors List of addresses that are allowed to execute proposals.
                address(0), ///           @param admin No admin necessary as proposers are preset upon deployment.
                deployer.account ///      @param canceller An additional canceller address with the rights to cancel awaiting proposals.
            )
        );
    }
}
