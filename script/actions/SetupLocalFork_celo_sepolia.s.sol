// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {ForkHelper, ISafeOwnerManager} from "lib/treb-sol/src/ForkHelper.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";

contract SetupLocalFork_celo_sepolia is TrebScript, ForkHelper {
    using Senders for Senders.Sender;

    address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    uint256 private constant BALANCES_SLOT = 0;
    uint256 private constant TOTAL_SUPPLY_SLOT = 2;
    uint256 private constant MINT_AMOUNT = 10_000_000 ether;

    /// @dev Safe storage slots (from SafeStorage.sol)
    address private constant SENTINEL_OWNERS = address(0x1);
    uint256 private constant SAFE_OWNERS_SLOT = 2;
    uint256 private constant SAFE_OWNER_COUNT_SLOT = 3;
    uint256 private constant SAFE_THRESHOLD_SLOT = 4;

    /// @custom:senders signer, deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage _signer = sender("signer");
        Senders.Sender storage _deployer = sender("deployer");
        Senders.Sender storage _migrationOwner = sender("migrationOwner");

        // 1. Convert Safe senders to 1/1 with signer as the sole owner.
        //    Uses Anvil RPC (not vm.store) so changes persist on the anvil node
        //    and are visible on both the simulation and execution forks.
        _ensureSafeIs1of1(_deployer, _signer.account, "deployer");
        _ensureSafeIs1of1(_migrationOwner, _signer.account, "migrationOwner");

        // 2. Replace GoldToken with standard ERC20 at CELO address
        MockCELO mock = new MockCELO();
        Anvil.setCodeRpc(CELO, address(mock).code);

        // 3. Mint CELO to all sender accounts
        _mintCELO(_signer.account, MINT_AMOUNT);
        _mintCELO(_deployer.account, MINT_AMOUNT);
        _mintCELO(_migrationOwner.account, MINT_AMOUNT);

        console.log("CELO (MockERC20) etched at:", CELO);
        console.log("  signer balance:", MockCELO(CELO).balanceOf(_signer.account));
        console.log("  deployer balance:", MockCELO(CELO).balanceOf(_deployer.account));
        console.log("  migrationOwner balance:", MockCELO(CELO).balanceOf(_migrationOwner.account));
    }

    function _ensureSafeIs1of1(Senders.Sender storage _sender, address _signerAddr, string memory label) internal {
        if (!_sender.isType(SenderTypes.GnosisSafe)) return;

        _convertSafeToSingleOwnerRpc(_sender.account, _signerAddr);

        console.log(string.concat("Converted ", label, " safe to 1/1:"));
        console.log("  safe:", _sender.account);
        console.log("  threshold:", ISafeOwnerManager(_sender.account).getThreshold());
        console.log("  signer is owner:", ISafeOwnerManager(_sender.account).isOwner(_signerAddr));
    }

    /// @dev Like ForkHelper.convertSafeToSingleOwner but uses Anvil RPC (anvil_setStorageAt)
    ///      instead of vm.store, so the changes persist on the underlying anvil node and are
    ///      visible on all forks (simulation + execution).
    function _convertSafeToSingleOwnerRpc(address safe, address newOwner) internal {
        require(newOwner != address(0) && newOwner != SENTINEL_OWNERS, "invalid owner");

        // Clear all existing owner mapping entries
        address[] memory currentOwners = ISafeOwnerManager(safe).getOwners();
        for (uint256 i = 0; i < currentOwners.length; i++) {
            bytes32 ownerSlot = keccak256(abi.encode(currentOwners[i], SAFE_OWNERS_SLOT));
            Anvil.setStorageAt(safe, ownerSlot, bytes32(0));
        }

        // Set up new single-owner linked list: sentinel -> newOwner -> sentinel
        bytes32 sentinelSlot = keccak256(abi.encode(SENTINEL_OWNERS, SAFE_OWNERS_SLOT));
        Anvil.setStorageAt(safe, sentinelSlot, bytes32(uint256(uint160(newOwner))));

        bytes32 newOwnerSlot = keccak256(abi.encode(newOwner, SAFE_OWNERS_SLOT));
        Anvil.setStorageAt(safe, newOwnerSlot, bytes32(uint256(uint160(SENTINEL_OWNERS))));

        // Set ownerCount = 1, threshold = 1
        Anvil.setStorageAt(safe, bytes32(SAFE_OWNER_COUNT_SLOT), bytes32(uint256(1)));
        Anvil.setStorageAt(safe, bytes32(SAFE_THRESHOLD_SLOT), bytes32(uint256(1)));
    }

    function _mintCELO(address to, uint256 amount) internal {
        bytes32 balanceSlot = keccak256(abi.encode(to, BALANCES_SLOT));
        Anvil.setStorageAt(CELO, balanceSlot, bytes32(amount));
        Anvil.setStorageAt(CELO, bytes32(TOTAL_SUPPLY_SLOT), bytes32(amount));
    }
}
