// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {ILiquityConfig} from "./ILiquityConfig.sol";

// ── Concrete configs ─────────────────────────────────────────────────────────
// Imported here so Foundry compiles their artifacts, enabling vm.deployCode()
// to find them by contract name at script run time.
import "./LiquityConfig_anvil_GBPm.sol";

/**
 * @notice Loader library used by deployment scripts.
 * @dev Set LIQUITY_CONFIG_CONTRACT env var to the concrete config contract name,
 *      e.g. LIQUITY_CONFIG_CONTRACT=LiquityConfig_anvil_GBPm
 *      vm.deployCode() instantiates the config locally in Foundry's simulation
 *      VM without broadcasting it as an on-chain transaction.
 */
library LiquityConfigLib {
    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function get()
        internal
        returns (ILiquityConfig.LiquityInstanceConfig memory)
    {
        string memory name = vm.envString("LIQUITY_CONFIG_CONTRACT");
        address config = vm.deployCode(name);
        require(
            config != address(0),
            string.concat("LiquityConfig: failed to deploy ", name)
        );
        return ILiquityConfig(config).get();
    }
}
