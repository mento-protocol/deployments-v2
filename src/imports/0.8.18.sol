// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

/**
 * @title Imports08
 * @notice This file imports all Mento protocol contracts that use Solidity 0.8.18
 *         to ensure they are compiled and their artifacts are available for deployment scripts.
 */

// Swap contracts (0.8.18)
import "lib/mento-core/contracts/swap/Broker.sol";

// Oracle contracts (0.8.18)
import "lib/mento-core/contracts/oracles/ChainlinkRelayerFactory.sol";
import "lib/mento-core/contracts/oracles/ChainlinkRelayerV1.sol";

// Token contracts (0.8.18)
import "lib/mento-core/contracts/tokens/StableTokenV2.sol";
