// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {ILiquityConfig} from "./ILiquityConfig.sol";

// ── Concrete configs ─────────────────────────────────────────────────────────
// Imported here so Foundry compiles their artifacts, enabling vm.deployCode()
// to find them by contract name at script run time.
import "./liquity/LiquityConfig_celo_sepolia_GBPm.sol";
import "./liquity/LiquityConfig_celo_GBPm.sol";

/**
 * @notice Loader library used by deployment scripts.
 * @dev Resolves the concrete config contract from the NETWORK env var and the
 *      token parameter, e.g. LiquityConfigLib.get("GBPm") on network "anvil"
 *      will deploy LiquityConfig_anvil_GBPm.
 *      vm.deployCode() instantiates the config locally in Foundry's simulation
 *      VM without broadcasting it as an on-chain transaction.
 */
library LiquityConfigLib {
    address private constant VM_ADDRESS =
        address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function get(
        string memory token
    ) internal returns (ILiquityConfig.LiquityInstanceConfig memory) {
        string memory network = vm.envString("NETWORK");
        string memory name = string.concat(
            "LiquityConfig_",
            network,
            "_",
            token
        );
        address config = vm.deployCode(name);
        require(
            config != address(0),
            string.concat("LiquityConfig: failed to deploy ", name)
        );
        return ILiquityConfig(config).get();
    }
}
