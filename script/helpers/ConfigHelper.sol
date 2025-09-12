// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Config, IMentoConfig, BreakerType} from "../config/Config.sol";

abstract contract ConfigHelper {
    IMentoConfig config;

    constructor() {
        config = Config.get(); // default config
    }

    function setConfig(IMentoConfig _config) public {
        config = _config;
    }
}
