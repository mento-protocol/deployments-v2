// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";

contract DeployBreakerBox is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address breakerBox;
    address medianDeltaBreaker;
    address valueDeltaBreaker;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        deployBreakerBox(deployer);
        deployBreakers(deployer);

        // Initialize BreakerBox with deployed breakers
        IBreakerBox breakerBoxContract = IBreakerBox(
            deployer.harness(breakerBox)
        );

        // Add MedianDeltaBreaker
        breakerBoxContract.addBreaker(medianDeltaBreaker, 1);

        // Add ValueDeltaBreaker
        breakerBoxContract.addBreaker(valueDeltaBreaker, 1);
    }

    function deployBreakers(Senders.Sender storage deployer) internal {
        address sortedOraclesProxy = lookup(
            "TransparentUpgradeableProxy:SortedOracles"
        );

        address owner = deployer.account;
        uint256 defaultCooldownTime;
        uint256 defaultRateChangeThreshold;
        address[] memory rateFeedIds = new address[](0);
        uint256[] memory defaultRateChangeThresholds = new uint256[](0);
        uint256[] memory cooldownTimes = new uint256[](0);

        // Deploy MedianDeltaBreaker
        medianDeltaBreaker = deployer
            .create3("MedianDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    defaultCooldownTime,
                    defaultRateChangeThreshold,
                    sortedOraclesProxy,
                    breakerBox,
                    rateFeedIds,
                    defaultRateChangeThresholds,
                    cooldownTimes,
                    owner
                )
            );

        // Deploy ValueDeltaBreaker
        valueDeltaBreaker = deployer
            .create3("ValueDeltaBreaker")
            .setLabel("v2.6.5")
            .deploy(
                abi.encode(
                    defaultCooldownTime,
                    defaultRateChangeThreshold,
                    sortedOraclesProxy,
                    rateFeedIds,
                    defaultRateChangeThresholds,
                    cooldownTimes,
                    owner
                )
            );
    }

    function deployBreakerBox(Senders.Sender storage deployer) internal {
        // Deploy BreakerBox with empty rate feed IDs and SortedOracles dependency
        address sortedOraclesProxy = lookup(
            "TransparentUpgradeableProxy:SortedOracles"
        );
        console.log(sortedOraclesProxy);
        address[] memory emptyRateFeedIDs = new address[](0);

        breakerBox = deployer.create3("BreakerBox").setLabel("v2.6.5").deploy(
            abi.encode(emptyRateFeedIDs, sortedOraclesProxy, deployer.account)
        );
    }
}
