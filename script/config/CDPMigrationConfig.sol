// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {ICDPMigrationConfig} from "./ICDPMigrationConfig.sol";
import {CDPMigrationConfig_celo_GBPm} from "./CDPMigrationConfig_celo_GBPm.sol";
import {CDPMigrationConfig_celo_sepolia_GBPm} from "./CDPMigrationConfig_celo_sepolia_GBPm.sol";

/**
 * @notice Loader library for CDP migration configs.
 * @dev Set CDP_MIGRATION_CONFIG_CONTRACT env var to the concrete config contract name,
 *      e.g. CDP_MIGRATION_CONFIG_CONTRACT=CDPMigrationConfig_anvil_GBPm
 *      vm.deployCode() instantiates the config locally in Foundry's simulation
 *      VM without broadcasting it as an on-chain transaction.
 */
library CDPMigrationConfigLib {
    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function get(string memory token)
        internal
        returns (ICDPMigrationConfig.CDPMigrationInstanceConfig memory)
    {
        string memory network = vm.envString("NETWORK");
        string memory name = string.concat(
            "CDPMigrationConfig_",
            network,
            "_",
            token
        );
        address config = vm.deployCode(name);
        require(
            config != address(0),
            string.concat("CDPMigrationConfig: failed to deploy ", name)
        );
        return ICDPMigrationConfig(config).get();
    }
}
