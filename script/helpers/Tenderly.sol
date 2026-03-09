// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library Tenderly {
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    // Network Customization Methods

    function setNextBlockTimestamp(uint256 timestamp) internal {
        vm.rpc("tenderly_setNextBlockTimestamp", string(abi.encodePacked('["', vm.toString(bytes32(timestamp)), '"]')));
    }

    // Balance Manipulation Methods

    function setBalance(address account, uint256 amount) internal {
        vm.rpc(
            "tenderly_setBalance",
            string(abi.encodePacked('[["', vm.toString(account), '"],"', vm.toString(bytes32(amount)), '"]'))
        );
    }

    function setBalances(address[] memory accounts, uint256 amount) internal {
        string memory accountsList = "[";
        for (uint256 i = 0; i < accounts.length; i++) {
            if (i > 0) {
                accountsList = string(abi.encodePacked(accountsList, ","));
            }
            accountsList = string(abi.encodePacked(accountsList, '"', vm.toString(accounts[i]), '"'));
        }
        accountsList = string(abi.encodePacked(accountsList, "]"));

        vm.rpc(
            "tenderly_setBalance", string(abi.encodePacked("[", accountsList, ',"', vm.toString(bytes32(amount)), '"]'))
        );
    }

    function addBalance(address account, uint256 amount) internal {
        vm.rpc(
            "tenderly_addBalance",
            string(abi.encodePacked('[["', vm.toString(account), '"],"', vm.toString(bytes32(amount)), '"]'))
        );
    }

    function setErc20Balance(address token, address wallet, uint256 value) internal {
        vm.rpc(
            "tenderly_setErc20Balance",
            string(
                abi.encodePacked(
                    '["', vm.toString(token), '","', vm.toString(wallet), '","', vm.toString(bytes32(value)), '"]'
                )
            )
        );
    }

    // Storage and Code Methods

    function setStorageAt(address target, bytes32 slot, bytes32 value) internal {
        vm.rpc(
            "tenderly_setStorageAt",
            string(
                abi.encodePacked('["', vm.toString(target), '","', vm.toString(slot), '","', vm.toString(value), '"]')
            )
        );
    }

    function setCode(address target, bytes memory code) internal {
        vm.rpc("tenderly_setCode", string(abi.encodePacked('["', vm.toString(target), '","', vm.toString(code), '"]')));
    }

    // State Management Methods

    function snapshot() internal returns (string memory) {
        bytes memory result = vm.rpc("evm_snapshot", "[]");
        return vm.toString(result);
    }

    function revertTo(string memory snapshotId) internal {
        vm.rpc("evm_revert", string(abi.encodePacked('["', snapshotId, '"]')));
    }
}
