// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Tenderly} from "./Tenderly.sol";

contract RevertSnapshot is Script {
    function run() public {
        // Try to read snapshot ID from file first
        string memory snapshotId;
        try vm.readFile("cache/.tenderly-snapshot") returns (
            string memory fileContent
        ) {
            snapshotId = fileContent;
            console.log(
                "Using snapshot ID from .tenderly-snapshot:",
                snapshotId
            );
        } catch {
            // If file doesn't exist, check if snapshot ID is provided as env variable
            snapshotId = vm.envString("SNAPSHOT_ID");
            console.log(
                "Using snapshot ID from SNAPSHOT_ID env var:",
                snapshotId
            );
        }

        Tenderly.revertTo(snapshotId);
    }

    function run(string memory snapshotId) public {
        console.log("Reverting to snapshot:", snapshotId);

        Tenderly.revertTo(snapshotId);
    }
}

