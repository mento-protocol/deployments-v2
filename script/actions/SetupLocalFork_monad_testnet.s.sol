// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";
import {SetupLocalFork, CELO} from "./SetupLocalFork.s.sol";

contract SetupLocalFork_celo_sepolia is TrebScript, SetupLocalFork {
    using Senders for Senders.Sender;

    /// @custom:senders deployer, migrationOwner
    function run() public override broadcast {
        Senders.Sender storage _deployer = sender("deployer");
        Senders.Sender storage _migrationOwner = sender("migrationOwner");

        // _mintGBPm(_migrationOwner.account, MINT_AMOUNT);
        // _mintUSDm(_migrationOwner.account, MINT_AMOUNT);
        // _mintUSDC(_migrationOwner.account, MINT_AMOUNT);
        // _mintAUSD(_migrationOwner.account, MINT_AMOUNT);
    }
}
