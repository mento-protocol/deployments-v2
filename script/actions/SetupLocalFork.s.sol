// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Anvil} from "../helpers/Anvil.sol";

address constant SAFE = 0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458;
address constant PROPOSER = 0x91606e52a843845669f1f25BbD5E95cb055a9707;

interface ISafe {
    function getThreshold() external view returns (uint256);

    function getOwners() external view returns (address[] memory);

    function isOwner(address owner) external view returns (bool);
}

contract SetupLocalFork is Script {
    // Safe storage slot positions
    uint256 constant OWNERS_MAPPING_SLOT = 2;
    uint256 constant OWNER_COUNT_SLOT = 3;
    uint256 constant THRESHOLD_SLOT = 4;

    // Safe constants
    address constant SENTINEL_OWNERS = address(0x1);

    function run() public {
        Anvil.setStorageAt(SAFE, bytes32(THRESHOLD_SLOT), bytes32(uint256(1)));

        bytes32 sentinelSlot = keccak256(
            abi.encode(SENTINEL_OWNERS, OWNERS_MAPPING_SLOT)
        );
        Anvil.setStorageAt(
            SAFE,
            sentinelSlot,
            bytes32(uint256(uint160(PROPOSER)))
        );

        bytes32 proposerSlot = keccak256(
            abi.encode(PROPOSER, OWNERS_MAPPING_SLOT)
        );
        Anvil.setStorageAt(
            SAFE,
            proposerSlot,
            bytes32(uint256(uint160(SENTINEL_OWNERS)))
        );

        Anvil.setStorageAt(
            SAFE,
            bytes32(OWNER_COUNT_SLOT),
            bytes32(uint256(1))
        );

        ISafe safe = ISafe(SAFE);
        uint256 newThreshold = safe.getThreshold();
        address[] memory owners = safe.getOwners();
        bool proposerIsOwner = safe.isOwner(PROPOSER);

        console.log("Safe configuration updated:");
        console.log("- Safe address:", SAFE);
        console.log("- New threshold:", newThreshold);
        console.log("- Total owners:", owners.length);
        if (owners.length > 0) {
            console.log("- Owner[0]:", owners[0]);
        }
        console.log("- Is PROPOSER an owner:", proposerIsOwner);
        console.log("- PROPOSER address:", PROPOSER);
    }
}
