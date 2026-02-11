// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MentoConfig} from "./MentoConfig.sol";

contract MentoConfig_local is MentoConfig {
    function _initialize() internal override {
        _oracleConfig = OracleConfig({reportExpirySeconds: 6 minutes});
    }
}
