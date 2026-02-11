// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

contract PostChecksHelper is TrebScript {
    constructor() {}

    function verifyOwnership(
        string memory identifier,
        address contractAddress,
        address expectedOwner
    ) internal view {
        require(
            IOwnable(contractAddress).owner() == expectedOwner,
            string.concat(identifier, " owner is not multisig")
        );
    }

    // TODO: Move this check to the test level and expect revert
    function verifyInitDisabled(
        string memory identifier,
        address impl
    ) internal view {
        // OpenZeppelin Initializable v4.x stores _initialized at slot 0 (lowest byte)
        bytes32 slot = bytes32(uint256(0));
        bytes32 value = vm.load(impl, slot);

        // _initialized is packed in the lowest byte of slot 0
        uint8 initialized = uint8(uint256(value));

        require(
            initialized == type(uint8).max,
            string.concat(identifier, " impl init is not disabled")
        );
    }
}
