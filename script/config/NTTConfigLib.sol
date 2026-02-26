// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {INTTConfig} from "./INTTConfig.sol";

// Imported so Foundry compiles their artifacts, enabling vm.deployCode().
import "./NTTConfig_USDm.sol";
import "./NTTConfig_GBPm.sol";

/// @notice Loader library for NTT bridge configs.
/// @dev Set NTT_CONFIG_CONTRACT env var to the concrete config contract name,
///      e.g. NTT_CONFIG_CONTRACT=NTTConfig_USDm
library NTTConfigLib {
    address private constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm private constant vm = Vm(VM_ADDRESS);

    function get() internal returns (INTTConfig.NTTTokenConfig memory) {
        string memory name = vm.envString("NTT_CONFIG_CONTRACT");
        address config = vm.deployCode(name);
        require(config != address(0), string.concat("NTTConfigLib: failed to deploy ", name));
        return INTTConfig(config).get();
    }
}
