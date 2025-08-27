// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";

import {addresses, uints} from "lib/mento-std/src/Array.sol";

interface IMentoToken {
    function emissionSupply() external returns (uint256);
}

contract DeployEmission is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        address mentoToken = lookup("MentoToken");
        address timelockController = predictProxy(
            ProxyType.OZTUP,
            deployer,
            "TimelockController"
        );

        address implementation = deployer
            .create3("Emission")
            .setLabel("v2.6.5")
            .deploy(abi.encode(true));

        deployProxy(
            ProxyType.OZTUP,
            deployer,
            "Emission",
            implementation,
            abi.encodeWithSignature(
                "initialize(address,address,uint256,address)",
                mentoToken,
                timelockController,
                IMentoToken(mentoToken).emissionSupply(),
                deployer.account
            )
        );
    }
}
