// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPausable {
    function pauser() external view returns (address);
    function transferPauserCapability(address newPauser) external;
}
