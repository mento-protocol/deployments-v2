// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

library Anvil {
    Vm constant vm =
        Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function setNextBlockTimestamp(uint256 timestamp) internal {
        vm.warp(timestamp);
    }

    function roll(uint256 blockNumber) internal {
        vm.roll(blockNumber);
    }

    function setBalance(address account, uint256 amount) internal {
        vm.deal(account, amount);
    }

    function setBalances(address[] memory accounts, uint256 amount) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            vm.deal(accounts[i], amount);
        }
    }

    function addBalance(address account, uint256 amount) internal {
        vm.deal(account, account.balance + amount);
    }

    function setErc20Balance(
        address token,
        address wallet,
        uint256 value,
        bytes32 slot
    ) internal {
        vm.store(token, keccak256(abi.encode(wallet, slot)), bytes32(value));
    }

    function setStorageAt(
        address target,
        bytes32 slot,
        bytes32 value
    ) internal {
        vm.store(target, slot, value);
    }

    function getStorageAt(
        address target,
        bytes32 slot
    ) internal view returns (bytes32) {
        return vm.load(target, slot);
    }

    function setCode(address target, bytes memory code) internal {
        vm.etch(target, code);
    }

    function snapshot() internal returns (uint256) {
        return vm.snapshot();
    }

    function revertTo(uint256 snapshotId) internal {
        vm.revertTo(snapshotId);
    }
}
