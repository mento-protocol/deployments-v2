// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {addresses, uints} from "lib/mento-std/src/Array.sol";

import {Config, IMentoConfig} from "../config/Config.sol";

contract DeployMentoGovernor is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        config = Config.get();
        IMentoConfig.GovernanceConfig memory govCfg = config
            .getGovernanceConfig();

        Senders.Sender storage deployer = sender("deployer");

        address implementation = deployer
            .create3("MentoGovernor")
            .setLabel("v2.6.5")
            .deploy(abi.encode(true));

        address locking = lookupProxyOrFail("Locking", ProxyType.OZTUP);
        address timelock = lookupProxyOrFail(
            "TimelockController",
            ProxyType.OZTUP
        );

        deployProxy(
            ProxyType.OZTUP,
            deployer,
            "MentoGovernor",
            implementation,
            abi.encodeWithSignature(
                "__MentoGovernor_init(address,address,uint256,uint256,uint256,uint256)",
                locking, ///                  @param veToken The escrowed Mento Token used for voting.
                timelock, ///                 @param timelockController The timelock controller used by the governor.
                govCfg.votingDelay, ///       @param votingDelay_ The delay time in blocks between the proposal creation and the start of voting.
                govCfg.votingPeriod, ///      @param votingPeriod_ The voting duration in blocks between the vote start and vote end.
                govCfg.proposalThreshold, /// @param threshold_ The number of votes required in order for a voter to become a proposer.
                govCfg.quorum ///             @param quorum_ The minimum number of votes in percent of total supply required in order for a proposal to succeed.
            )
        );
    }
}
