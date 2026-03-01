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

    function setErc20BalanceRpc(
        address token,
        address wallet,
        uint256 value,
        bytes32 slot
    ) internal {
        bytes32 balanceSlot = keccak256(abi.encode(wallet, slot));
        setStorageAt(token, balanceSlot, bytes32(value));
    }

    function setStorageAt(
        address target,
        bytes32 slot,
        bytes32 value
    ) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "anvil_setStorageAt",
                string(
                    abi.encodePacked(
                        '["',
                        vm.toString(target),
                        '","',
                        vm.toString(slot),
                        '","',
                        vm.toString(value),
                        '"]'
                    )
                )
            )
        );
        require(success);
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

    function setCodeRpc(address target, bytes memory code) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "anvil_setCode",
                string(
                    abi.encodePacked(
                        '["',
                        vm.toString(target),
                        '","',
                        vm.toString(code),
                        '"]'
                    )
                )
            )
        );
        require(success, "anvil_setCode failed");
    }

    function setBalanceRpc(address account, uint256 amount) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "anvil_setBalance",
                string(
                    abi.encodePacked(
                        '["',
                        vm.toString(account),
                        '","',
                        vm.toString(bytes32(amount)),
                        '"]'
                    )
                )
            )
        );
        require(success, "anvil_setBalance failed");
    }

    function impersonateAccount(address account) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "anvil_impersonateAccount",
                string(abi.encodePacked('["', vm.toString(account), '"]'))
            )
        );
        require(success, "anvil_impersonateAccount failed");
    }

    function stopImpersonatingAccount(address account) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "anvil_stopImpersonatingAccount",
                string(abi.encodePacked('["', vm.toString(account), '"]'))
            )
        );
        require(success, "anvil_stopImpersonatingAccount failed");
    }

    function sendTransaction(address from, address to, bytes memory data) internal {
        (bool success, ) = address(vm).call(
            abi.encodeWithSignature(
                "rpc(string,string)",
                "eth_sendTransaction",
                string(
                    abi.encodePacked(
                        '[{"from":"',
                        vm.toString(from),
                        '","to":"',
                        vm.toString(to),
                        '","data":"',
                        vm.toString(data),
                        '"}]'
                    )
                )
            )
        );
        require(success, "eth_sendTransaction failed");
    }

    function snapshot() internal returns (uint256) {
        return vm.snapshot();
    }

    function revertTo(uint256 snapshotId) internal {
        vm.revertTo(snapshotId);
    }
}
