// SPDX-License-Identifier: MIT
pragma solidity ^0.5.13;

/**
 * @title Imports
 * @notice This file imports all Mento protocol contracts to ensure they are compiled
 *         and their artifacts are available for deployment scripts.
 *         Uses Solidity 0.5.13 to match the older contracts.
 */

// Swap contracts (0.5.13)
import {BiPoolManager} from "lib/mento-core/contracts/swap/BiPoolManager.sol";
import {Reserve} from "lib/mento-core/contracts/swap/Reserve.sol";
import {ConstantSumPricingModule} from "lib/mento-core/contracts/swap/ConstantSumPricingModule.sol";
import {ConstantProductPricingModule} from "lib/mento-core/contracts/swap/ConstantProductPricingModule.sol";

// Oracle contracts (0.5.13)
import {BreakerBox} from "lib/mento-core/contracts/oracles/BreakerBox.sol";
import {MedianDeltaBreaker} from "lib/mento-core/contracts/oracles/breakers/MedianDeltaBreaker.sol";
import {ValueDeltaBreaker} from "lib/mento-core/contracts/oracles/breakers/ValueDeltaBreaker.sol";

// Note: The following contracts use Solidity 0.8.18 and cannot be imported here:
// - Broker
// - ChainlinkRelayerFactory
// - ChainlinkRelayerV1
// - StableTokenV2
// They will be compiled separately when their respective files are processed.
