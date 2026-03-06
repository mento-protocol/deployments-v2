// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {V3IntegrationBase} from "./V3IntegrationBase.t.sol";
import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IChainlinkRelayerFactory} from "lib/mento-core/contracts/interfaces/IChainlinkRelayerFactory.sol";
import {ISortedOracles} from "mento-core/interfaces/ISortedOracles.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";

/**
 * @title ChainlinkRelayerVerification
 * @notice Verifies that deployed ChainlinkRelayer contracts match config:
 *         - rateFeedDescription matches on-chain
 *         - maxTimestampSpread matches on-chain
 *         - aggregators[] (addresses and invert flags) match on-chain
 *         - Each relayer is registered as an oracle for its rate feed in SortedOracles
 */
contract ChainlinkRelayerVerification is V3IntegrationBase {
    address internal chainlinkRelayerFactory;

    function setUp() public override {
        super.setUp();
        chainlinkRelayerFactory = lookupProxyOrFail("ChainlinkRelayerFactory");
    }

    // ========== Relayer Existence ==========

    /// @notice Every configured relayer must be deployed via the factory
    function test_allRelayerConfigs_deployedViaFactory() public view {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();
        assertGt(cfgs.length, 0, "No chainlink relayer configs");

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            assertNotEq(
                relayer,
                address(0),
                string.concat(
                    "Relayer not deployed for rate feed '",
                    cfgs[i].rateFeed,
                    "' (ID: ",
                    vm.toString(cfgs[i].rateFeedId),
                    ")"
                )
            );
        }
    }

    // ========== rateFeedDescription ==========

    /// @notice Each relayer's on-chain rateFeedDescription must match config
    function test_allRelayerConfigs_rateFeedDescriptionMatches() public {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            string memory actual = IChainlinkRelayer(relayer).rateFeedDescription();
            assertEq(
                keccak256(bytes(actual)),
                keccak256(bytes(cfgs[i].rateFeedDescription)),
                string.concat(
                    "rateFeedDescription mismatch for '",
                    cfgs[i].rateFeed,
                    "': expected='",
                    cfgs[i].rateFeedDescription,
                    "' actual='",
                    actual,
                    "'"
                )
            );
        }
    }

    // ========== maxTimestampSpread ==========

    /// @notice Each relayer's on-chain maxTimestampSpread must match config
    function test_allRelayerConfigs_maxTimestampSpreadMatches() public {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            uint256 actual = IChainlinkRelayer(relayer).maxTimestampSpread();
            assertEq(
                actual,
                cfgs[i].maxTimestampSpread,
                string.concat(
                    "maxTimestampSpread mismatch for '",
                    cfgs[i].rateFeed,
                    "': expected=",
                    vm.toString(cfgs[i].maxTimestampSpread),
                    " actual=",
                    vm.toString(actual)
                )
            );
        }
    }

    // ========== Aggregators ==========

    /// @notice Each relayer's on-chain aggregator count must match config
    function test_allRelayerConfigs_aggregatorCountMatches() public {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            IChainlinkRelayer.ChainlinkAggregator[] memory actual = IChainlinkRelayer(relayer).getAggregators();
            assertEq(
                actual.length,
                cfgs[i].aggregators.length,
                string.concat(
                    "Aggregator count mismatch for '",
                    cfgs[i].rateFeed,
                    "': expected=",
                    vm.toString(cfgs[i].aggregators.length),
                    " actual=",
                    vm.toString(actual.length)
                )
            );
        }
    }

    /// @notice Each relayer's on-chain aggregator addresses must match config
    function test_allRelayerConfigs_aggregatorAddressesMatch() public {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            IChainlinkRelayer.ChainlinkAggregator[] memory actual = IChainlinkRelayer(relayer).getAggregators();
            // Q: why not assertEq(cfgs[i].aggregators.length, actual.length)?
            uint256 len = cfgs[i].aggregators.length < actual.length ? cfgs[i].aggregators.length : actual.length;

            for (uint256 j = 0; j < len; j++) {
                assertEq(
                    actual[j].aggregator,
                    cfgs[i].aggregators[j].aggregator,
                    string.concat(
                        "Aggregator address mismatch for '",
                        cfgs[i].rateFeed,
                        "' at index ",
                        vm.toString(j),
                        ": expected=",
                        vm.toString(cfgs[i].aggregators[j].aggregator),
                        " actual=",
                        vm.toString(actual[j].aggregator)
                    )
                );
            }
        }
    }

    /// @notice Each relayer's on-chain aggregator invert flags must match config
    function test_allRelayerConfigs_aggregatorInvertFlagsMatch() public {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            IChainlinkRelayer.ChainlinkAggregator[] memory actual = IChainlinkRelayer(relayer).getAggregators();
            uint256 len = cfgs[i].aggregators.length < actual.length ? cfgs[i].aggregators.length : actual.length;

            for (uint256 j = 0; j < len; j++) {
                assertEq(
                    actual[j].invert,
                    cfgs[i].aggregators[j].invert,
                    string.concat(
                        "Aggregator invert mismatch for '",
                        cfgs[i].rateFeed,
                        "' at index ",
                        vm.toString(j),
                        ": expected=",
                        vm.toString(cfgs[i].aggregators[j].invert),
                        " actual=",
                        vm.toString(actual[j].invert)
                    )
                );
            }
        }
    }

    // ========== SortedOracles Registration ==========

    /// @notice Each relayer must be registered as an oracle for its rate feed in SortedOracles
    function test_allRelayerConfigs_registeredAsSortedOraclesOracle() public view {
        IMentoConfig.ChainlinkRelayerConfig[] memory cfgs = config.getChainlinkRelayerConfigs();

        for (uint256 i = 0; i < cfgs.length; i++) {
            address relayer = IChainlinkRelayerFactory(chainlinkRelayerFactory).getRelayer(cfgs[i].rateFeedId);
            if (relayer == address(0)) continue;

            assertTrue(
                ISortedOracles(sortedOracles).isOracle(cfgs[i].rateFeedId, relayer),
                string.concat(
                    "Relayer not registered as oracle in SortedOracles for '",
                    cfgs[i].rateFeed,
                    "' (relayer=",
                    vm.toString(relayer),
                    ", rateFeedId=",
                    vm.toString(cfgs[i].rateFeedId),
                    ")"
                )
            );
        }
    }
}
