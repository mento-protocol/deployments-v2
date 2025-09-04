// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Tenderly} from "../helpers/Tenderly.sol";

contract CreateSnapshot is Script {
    function run() public returns (string memory) {
        string memory snapshotId = Tenderly.snapshot();

        console.log("Created snapshot with ID:", snapshotId);

        // Optionally write the snapshot ID to a file for later use
        vm.writeFile("cache/.tenderly-snapshot", snapshotId);
        console.log("Snapshot ID saved to .tenderly-snapshot");

        return snapshotId;
    }
}
