// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CommonBase} from "forge-std/Base.sol";
import {ICeloProxy} from "mento-core/interfaces/ICeloProxy.sol";

/// @dev Lightweight proxy introspection helpers usable from both scripts and tests.
abstract contract ProxyViewHelper is CommonBase {
    function getProxyImplementation(address proxy) internal view returns (address) {
        try ICeloProxy(proxy)._getImplementation() returns (address impl) {
            if (impl != address(0)) {
                return impl;
            }
        } catch {}

        // Fall back to EIP-1967 implementation slot (OZTUP)
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxy, implSlot))));
    }

    function getProxyAdmin(address proxy) internal view returns (address) {
        return
            address(
                uint160(uint256(vm.load(proxy, 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)))
            );
    }
}
