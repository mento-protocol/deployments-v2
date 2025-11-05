// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

/**
 * @title Imports08
 * @notice This file imports all Mento protocol contracts that use Solidity 0.8.18
 *         to ensure they are compiled and their artifacts are available for deployment scripts.
 */

// Token contracts (0.8.18)
import {StableTokenV2} from "lib/mento-core/contracts/tokens/StableTokenV2.sol";

// Governance (0.8.18)
import {MentoToken} from "lib/mento-core/contracts/governance/MentoToken.sol";
import {Emission} from "lib/mento-core/contracts/governance/Emission.sol";
import {Locking} from "lib/mento-core/contracts/governance/locking/Locking.sol";
import {TimelockController} from "lib/mento-core/contracts/governance/TimelockController.sol";
import {MentoGovernor} from "lib/mento-core/contracts/governance/MentoGovernor.sol";
