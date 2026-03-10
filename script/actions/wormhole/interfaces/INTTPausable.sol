// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INTTPausable {
    function isPaused() external view returns (bool);
    function pause() external;
    function unpause() external;
}
