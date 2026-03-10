// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INttDeployHelper {
    function nttManagerProxy() external view returns (address);
    function nttManagerImpl() external view returns (address);
    function transceiverProxy() external view returns (address);
    function transceiverImpl() external view returns (address);
}
