// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {CreateExchangePools} from "./CreateExchangePools.s.sol";
import {DestroyExchangePools} from "./DestroyExchangePools.s.sol";

contract RecreateExchangePools is DestroyExchangePools, CreateExchangePools {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    /// @custom:env {bytes32:optional} exchangeId
    function run()
        public
        override(DestroyExchangePools, CreateExchangePools)
        broadcast
    {
        DestroyExchangePools.run();
        CreateExchangePools.run();
    }
}
