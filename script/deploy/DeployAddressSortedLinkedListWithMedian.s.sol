// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

contract DeployAddressSortedLinkedListWithMedian is TrebScript {
    using Senders for Senders.Sender;
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;

    /**
     * @custom:senders deployer
     */
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        deployer.create2("AddressSortedLinkedListWithMedian").deploy();
    }
}
