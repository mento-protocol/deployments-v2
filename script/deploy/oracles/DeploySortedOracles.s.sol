// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "lib/treb-sol/src/internal/sender/Deployer.sol";

import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

contract DeploySortedOracles is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        IMentoConfig config = Config.get();

        address sortedOraclesImpl = deployer.create3("SortedOracles").setLabel("v2.6.5").deploy(abi.encode(false));

        address sortedOraclesProxy = deployProxy(deployer, "SortedOracles", sortedOraclesImpl, "");

        ISortedOracles sortedOracles = ISortedOracles(deployer.harness(sortedOraclesProxy));
        sortedOracles.initialize(config.getOracleConfig().reportExpirySeconds);
    }
}
