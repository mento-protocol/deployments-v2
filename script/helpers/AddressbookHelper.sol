// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";

contract AddressbookHelper is TrebScript {
    string private json;
    string private namespace;

    constructor() {
        namespace = vm.envOr("NAMESPACE", string("default"));
        try vm.readFile(".treb/addressbook.json") returns (string memory _json) {
            json = _json;
        } catch {
            revert("AddressbookHelper: failed to load .treb/addressbook.json");
        }
    }

    function lookupAddressbook(string memory _identifier) internal view returns (address) {
        string memory jsonPath = string.concat(".", namespace, "[\"", _identifier, "\"]");
        try vm.parseJsonAddress(json, jsonPath) returns (address result) {
            return result;
        } catch {
            revert(string.concat("AddressbookHelper: '", _identifier, "' not found in namespace '", namespace, "'"));
        }
    }
}
