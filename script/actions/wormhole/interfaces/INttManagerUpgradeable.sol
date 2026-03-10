// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INttManagerUpgradeable {
    function upgrade(address newImplementation) external;
}
