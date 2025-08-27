// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Tenderly} from "./Tenderly.sol";

address constant SAFE = 0x32CB58b145d3f7e28c45cE4B2Cc31fa94248b23F;
address constant PROPOSER = 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81;

interface ISafe {
    function getThreshold() external view returns (uint256);

    function getOwners() external view returns (address[] memory);

    function isOwner(address owner) external view returns (bool);
}

contract SetupVirtualNetwork is Script {
    // Safe storage slot positions
    uint256 constant OWNERS_MAPPING_SLOT = 2;
    uint256 constant OWNER_COUNT_SLOT = 3;
    uint256 constant THRESHOLD_SLOT = 4;

    // Safe constants
    address constant SENTINEL_OWNERS = address(0x1);

    function run() public {
        // 1. Set threshold to 1
        Tenderly.setStorageAt(
            SAFE,
            bytes32(THRESHOLD_SLOT),
            bytes32(uint256(1))
        );

        // 2. Clear existing owners by setting SENTINEL_OWNERS to point to itself
        bytes32 sentinelSlot = keccak256(
            abi.encode(SENTINEL_OWNERS, OWNERS_MAPPING_SLOT)
        );
        Tenderly.setStorageAt(
            SAFE,
            sentinelSlot,
            bytes32(uint256(uint160(SENTINEL_OWNERS)))
        );

        // 3. Add PROPOSER as the only owner
        // SENTINEL_OWNERS -> PROPOSER
        Tenderly.setStorageAt(
            SAFE,
            sentinelSlot,
            bytes32(uint256(uint160(PROPOSER)))
        );

        // PROPOSER -> SENTINEL_OWNERS (complete the linked list)
        bytes32 proposerSlot = keccak256(
            abi.encode(PROPOSER, OWNERS_MAPPING_SLOT)
        );
        Tenderly.setStorageAt(
            SAFE,
            proposerSlot,
            bytes32(uint256(uint160(SENTINEL_OWNERS)))
        );

        // 4. Set owner count to 1
        Tenderly.setStorageAt(
            SAFE,
            bytes32(OWNER_COUNT_SLOT),
            bytes32(uint256(1))
        );

        // Query and log the changes
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
