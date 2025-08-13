// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {Config} from "../config/Config.sol";
import {IMentoConfig} from "../interfaces/IMentoConfig.sol";
import {ITrebEvents} from "lib/treb-sol/src/internal/ITrebEvents.sol";
import {Harness} from "lib/treb-sol/src/internal/Harness.sol";

contract ConfigureChainlinkRelayers is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();

        Senders.Sender storage deployer = sender("deployer");

        // Check if ChainlinkRelayerFactory is deployed
        address chainlinkRelayerFactoryProxy = lookup(
            "TransparentUpgradeableProxy:ChainlinkRelayerFactory"
        );
        if (chainlinkRelayerFactoryProxy == address(0)) {
            console.log(
                "ChainlinkRelayerFactory not deployed, skipping Chainlink configuration"
            );
            return;
        }

        // Get SortedOracles
        address sortedOraclesProxy = lookup(
            "TransparentUpgradeableProxy:SortedOracles"
        );
        require(sortedOraclesProxy != address(0), "SortedOracles not deployed");

        IChainlinkRelayerFactory factory = IChainlinkRelayerFactory(
            deployer.harness(chainlinkRelayerFactoryProxy)
        );
        ISortedOracles sortedOracles = ISortedOracles(
            deployer.harness(sortedOraclesProxy)
        );

        // Get Chainlink relayer configurations from config
        IMentoConfig.ChainlinkRelayerConfig[] memory relayerConfigs = config
            .getChainlinkRelayerConfigs();

        if (relayerConfigs.length == 0) {
            console.log("No Chainlink relayers configured");
            return;
        }

        for (uint256 i = 0; i < relayerConfigs.length; i++) {
            // Deploy relayer through factory
            address relayer = factory.deployRelayer(
                relayerConfigs[i].rateFeedId,
                relayerConfigs[i].rateFeedDescription,
                relayerConfigs[i].maxTimestampSpread,
                relayerConfigs[i].aggregators
            );

            bytes memory constructorArgs = abi.encode(
                relayerConfigs[i].rateFeedId,
                relayerConfigs[i].rateFeedDescription,
                relayerConfigs[i].maxTimestampSpread,
                relayerConfigs[i].aggregators
            );

            bytes memory chainlinkRelayerV1Code = vm.getCode(
                "ChainlinkRelayerV1"
            );

            /// Manual emit of treb ContractDeployed event so we record the relayer
            /// in the treb registry.
            emit ITrebEvents.ContractDeployed(
                address(factory),
                relayer,
                Harness(payable(address(factory))).lastTransactionId(),
                ITrebEvents.DeploymentDetails({
                    artifact: "ChainlinkRelayerV1",
                    label: relayerConfigs[i].rateFeed,
                    entropy: "",
                    salt: keccak256("mento.chainlinkRelayer"),
                    bytecodeHash: keccak256(chainlinkRelayerV1Code),
                    initCodeHash: keccak256(
                        abi.encode(chainlinkRelayerV1Code, constructorArgs)
                    ),
                    constructorArgs: constructorArgs,
                    createStrategy: "CREATE2"
                })
            );

            console.log(
                string.concat(
                    "Deployed Chainlink relayer for ",
                    relayerConfigs[i].rateFeed
                ),
                relayer
            );

            // Add relayer as oracle for this rate feed
            sortedOracles.addOracle(relayerConfigs[i].rateFeedId, relayer);
            IChainlinkRelayer(deployer.harness(relayer)).relay();
        }

        console.log("Configured", relayerConfigs.length, "Chainlink relayers");
    }
}

