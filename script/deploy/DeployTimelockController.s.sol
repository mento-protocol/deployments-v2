// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {addresses, uints} from "lib/mento-std/src/Array.sol";

contract DeployTimelockController is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    uint256 public constant GOVERNANCE_TIMELOCK_DELAY = 2 days;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        address mentoGovernor = predictProxy(
            ProxyType.OZTUP,
            deployer,
            "MentoGovernor"
        );

        address implementation = deployer
            .create3("TimelockController")
            .setLabel("v2.6.5")
            .deploy(abi.encode(true));

        address[] memory proposers = addresses(mentoGovernor); // only Governor can propose
        address[] memory executors = addresses(address(0)); // anybody can execute

        deployProxy(
            ProxyType.OZTUP,
            deployer,
            "TimelockController",
            implementation,
            abi.encodeWithSignature(
                "__MentoTimelockController_init(uint256,address[],address[],address,address)",
                GOVERNANCE_TIMELOCK_DELAY, /// @param minDelay The minimum delay before a proposal can be executed.
                proposers, ///                 @param proposers List of addresses that are allowed to queue AND cancel operations.
                executors, ///                 @param executors List of addresses that are allowed to execute proposals.
                address(0), ///                @param admin No admin necessary as proposers are preset upon deployment.
                deployer.account ///           @param canceller An additional canceller address with the rights to cancel awaiting proposals.
            )
        );
    }
}
