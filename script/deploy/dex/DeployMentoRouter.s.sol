// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

contract DeployMentoRouter is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        deployer.create3("MentoRouter").setLabel("v1.0.0").deploy(
            abi.encode(lookupProxyOrFail("Broker"), deployer.account)
        );
    }
}
