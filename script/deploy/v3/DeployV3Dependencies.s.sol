// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";

import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";

contract DeployV3Depdendencies is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address sortedOraclesImpl;
    address sortedOracles;
    address breakerBox;

    string label = "v3.0.1";

    /// @custom:senders deployer,multisig
    function run() public broadcast {
        Senders.Sender storage deployer = sender("multisig");

        sortedOraclesImpl = deployer
            .create3("SortedOracles")
            .setLabel(label)
            .deploy(abi.encode(false));

        sortedOracles = deployProxy(
            deployer,
            "SortedOracles",
            sortedOraclesImpl,
            abi.encodeWithSelector(
                ISortedOracles.initialize.selector,
                uint256(360)
            )
        );

        address[] memory rateFeedIds = new address[](0);
        breakerBox = deployer.create3("BreakerBox").setLabel(label).deploy(
            abi.encode(rateFeedIds, sortedOracles, deployer.account)
        );
    }
}
