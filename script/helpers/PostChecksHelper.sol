// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

contract PostChecksHelper is TrebScript {
    constructor() {}

    function verifyInit(
        string memory identifier,
        address current,
        address expected
    ) internal pure {
        require(
            current == expected,
            string.concat(identifier, " initialized with mismatched address")
        );
    }

    function verifyFPMMFactoryParams(
        string memory identifier,
        uint256 current,
        uint256 expected
    ) internal pure {
        require(
            current == expected,
            string.concat(identifier, " param mismatched")
        );
    }

    function verifyFPMMFactoryParams(
        string memory identifier,
        address current,
        address expected
    ) internal pure {
        require(
            current == expected,
            string.concat(identifier, " param mismatched")
        );
    }

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

    function verifyCeloInitDisabled(
        string memory identifier,
        address impl
    ) internal view {
        // Celo's Initializable exposes a public `initialized` getter
        (bool success, bytes memory data) = impl.staticcall(
            abi.encodeWithSignature("initialized()")
        );
        require(
            success,
            string.concat(identifier, " initialized() call failed")
        );
        bool isInitialized = abi.decode(data, (bool));
        require(
            isInitialized,
            string.concat(identifier, " impl init is not disabled")
        );
    }
}
