// SPDX-License-Identifier: MIT
pragma solidity ^0.5;

import {Proxy as CeloProxy} from "@celo/common/Proxy.sol";

contract Proxy is CeloProxy {
    constructor(address initialOwner) public {
        _setOwner(initialOwner);
    }
}
