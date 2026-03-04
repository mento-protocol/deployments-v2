// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITransceiver {
    function setWormholePeer(uint16 chainId, bytes32 peerContract) external payable;
    function getWormholePeer(uint16 chainId) external view returns (bytes32);
}
