// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WormholeConfig} from "./WormholeConfig.sol";

contract WormholeConfig_mainnet is WormholeConfig("mainnet") {
    constructor() {
        _registerToken("USDm", 18, "MigrationMultisig");
        _registerToken("GBPm", 18, "MigrationMultisig");
    }
}
