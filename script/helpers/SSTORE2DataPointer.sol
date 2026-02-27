// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "Solady/utils/SSTORE2.sol";

/// @notice Wrapper that calls SSTORE2.write in its constructor,
///         making the SSTORE2 data deployable via create3.
contract SSTORE2DataPointer {
    address public immutable pointer;

    constructor(bytes memory _data) {
        pointer = SSTORE2.write(_data);
    }
}
