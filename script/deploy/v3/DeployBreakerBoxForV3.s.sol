// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {ProxyHelper, ProxyType, OZTUP_ARTIFACT} from "script/helpers/ProxyHelper.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";

contract DeployBreakerBoxForV3 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    string label = "v3.0.0";

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address sortedOracles = lookupProxyOrFail("SortedOracles");

        address[] memory rateFeedIds = new address[](0);
        address breakerBox = deployer
            .create3("BreakerBox")
            .setLabel(label)
            .deploy(abi.encode(rateFeedIds, sortedOracles, deployer.account));

        // TODO: Create necessary breakers
    }
}
