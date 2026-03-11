// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2 as console} from "forge-std/console2.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {TransceiverStructs} from "mento-stabletoken-ntt/src/libraries/TransceiverStructs.sol";

/// @title DeployTransceiverStructs
/// @notice Deploys the TransceiverStructs library via CREATE3.
///
/// @dev This library is required by NttManager and WormholeTransceiver.
///      It must be deployed before DeployNTT and its address passed to forge
///      via the --libraries flag so that NttDeployHelper bytecode can be linked.
///
///      Usage:
///        treb run DeployTransceiverStructs --network monad --debug
contract DeployTransceiverStructs is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address lib = deployer.create3("TransceiverStructs").deploy(bytes(""));
    }
}
