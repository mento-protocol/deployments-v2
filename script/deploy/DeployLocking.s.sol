// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {addresses, uints} from "lib/mento-std/src/Array.sol";

import {Config, IMentoConfig} from "../config/Config.sol";

interface IMentoToken {
    function emissionSupply() external returns (uint256);
}

contract DeployLocking is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:senders deployer
    function run() public broadcast {
        config = Config.get();
        IMentoConfig.LockingConfig memory lockingCfg = config
            .getLockingConfig();

        Senders.Sender storage deployer = sender("deployer");
        address mentoToken = lookup("MentoToken");

        address implementation = deployer
            .create3("Locking")
            .setLabel("v2.6.5")
            .deploy(abi.encode(true));

        deployProxy(
            ProxyType.OZTUP,
            deployer,
            "Locking",
            implementation,
            abi.encodeWithSignature(
                "__Locking_init(address,uint32,uint32,uint32,address)",
                mentoToken, ///                   @param _token The token to be locked in exchange for voting power in form of veTokens.
                lockingCfg.startingPointWeek, /// @param _startingPointWeek The locking epoch start in weeks. We start the locking contract from week 1 with min slope duration of 1
                lockingCfg.minCliffPeriod, ///    @param _minCliffPeriod minimum cliff period in weeks.
                lockingCfg.minSlopePeriod, ///    @param _minSlopePeriod minimum slope period in weeks.
                deployer.account ///              @param _initialOwner the initial owner of the contract
            )
        );
    }
}
