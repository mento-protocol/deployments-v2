// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {MentoConfig} from "./MentoConfig.sol";
import {IMentoV3Config} from "./IMentoV3Config.sol";

abstract contract MentoV3Config is MentoConfig, IMentoV3Config {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

}
