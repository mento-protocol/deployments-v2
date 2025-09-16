// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {addresses, uints} from "lib/mento-std/src/Array.sol";

import {ProxyHelper, ProxyType} from "script/helpers/ProxyHelper.sol";

contract DeployMentoToken is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        address timelockController = predictProxy(
            ProxyType.OZTUP,
            deployer,
            "TimelockController"
        );
        address emissions = predictProxy(
            ProxyType.OZTUP,
            deployer,
            "Emissions"
        );
        address locking = predictProxy(ProxyType.OZTUP, deployer, "Locking");

        deployer.create3("MentoToken").deploy(
            abi.encode(
                addresses(deployer.account, timelockController),
                uints(200, 200),
                emissions,
                locking,
                deployer.account
            )
        );
    }
}
