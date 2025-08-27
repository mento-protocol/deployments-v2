// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {addresses, uints} from "lib/mento-std/src/Array.sol";

contract DeployMentoGovernor is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    uint256 public constant GOVERNOR_VOTING_DELAY = 0; // Delay time in blocks between proposal creation and the start of voting.
    uint256 public constant GOVERNOR_VOTING_PERIOD = 120_960; // Voting period in blocks for the governor (7 days in blocks CELO)
    uint256 public constant GOVERNOR_PROPOSAL_THRESHOLD = 10_000e18;
    uint256 public constant GOVERNOR_QUORUM = 2; // Quorum percentage for the governor

    /// @custom:senders deployer
    function run() public broadcast {
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
                locking, ///                     @param veToken The escrowed Mento Token used for voting.
                timelock, ///                    @param timelockController The timelock controller used by the governor.
                GOVERNOR_VOTING_DELAY, ///       @param votingDelay_ The delay time in blocks between the proposal creation and the start of voting.
                GOVERNOR_VOTING_PERIOD, ///      @param votingPeriod_ The voting duration in blocks between the vote start and vote end.
                GOVERNOR_PROPOSAL_THRESHOLD, /// @param threshold_ The number of votes required in order for a voter to become a proposer.
                GOVERNOR_QUORUM ///              @param quorum_ The minimum number of votes in percent of total supply required in order for a proposal to succeed.
            )
        );
    }
}
