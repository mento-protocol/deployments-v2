// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ForkHelper, ISafeOwnerManager} from "lib/treb-sol/src/ForkHelper.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {CeloTransferPrecompile} from "../helpers/CeloTransferPrecompile.sol";
import {MockCELO} from "../helpers/MockCELO.sol";

address constant SAFE = 0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458;
address constant PROPOSER = 0x91606e52a843845669f1f25BbD5E95cb055a9707;
address constant DEPLOYER = 0x2738F38Fde510743e0c589415E0598C4ceE6eAa7;
address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
address constant TRANSFER_PRECOMPILE = address(0xff - 2);

interface ISafeOwnerMgr {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 _threshold) external;
    function changeThreshold(uint256 _threshold) external;
}

contract SetupLocalFork is ForkHelper, Script {
    uint256 private constant BALANCES_SLOT = 0;
    uint256 private constant TOTAL_SUPPLY_SLOT = 2;
    uint256 internal constant MINT_AMOUNT = 10_000_000 ether;
    address internal constant SENTINEL_OWNERS = address(0x1);

    function run() public virtual {
        // 1. Convert Safe to single-owner for fork testing
        // convertSafeToSingleOwner(SAFE, PROPOSER);

        // 2. Etch no-op transfer precompile (safety net)
        // CeloTransferPrecompile precompileHandler = new CeloTransferPrecompile();
        // Anvil.setCodeRpc(TRANSFER_PRECOMPILE, address(precompileHandler).code);

        if (block.chainid != 42220 && block.chainid != 11142220) {
            return;
        }
        // 3. Replace GoldToken with standard ERC20 at CELO address
        MockCELO mock = new MockCELO();
        Anvil.setCodeRpc(CELO, address(mock).code);

        // -- Verify --
        // console.log("Safe configuration updated:");
        // console.log("  address:", SAFE);
        // console.log("  threshold:", ISafeOwnerManager(SAFE).getThreshold());
        // console.log("  PROPOSER is owner:", ISafeOwnerManager(SAFE).isOwner(PROPOSER));

        console.log("CELO (MockERC20) etched at:", CELO);
        console.log("  PROPOSER balance:", MockCELO(CELO).balanceOf(PROPOSER));
        console.log("  DEPLOYER balance:", MockCELO(CELO).balanceOf(DEPLOYER));

        // console.log("Transfer precompile etched at:", TRANSFER_PRECOMPILE);
    }

    /// @dev Converts a Safe to single-owner 1/1 by calling the Safe's own
    ///      OwnerManager functions. This works regardless of storage layout
    ///      (handles Celo's custom Safe implementation).
    ///      Changes are applied on both:
    ///        - Current fork via vm.prank (updates simulation fork cache)
    ///        - Anvil node via impersonation + sendTransaction (persists for
    ///          execution fork and subsequent scripts)
    function _convertSafeToSingleOwner(address safe, address newOwner) internal {
        require(newOwner != address(0) && newOwner != SENTINEL_OWNERS, "invalid owner");

        ISafeOwnerMgr safeMgr = ISafeOwnerMgr(safe);
        address[] memory currentOwners = safeMgr.getOwners();
        bool alreadyOwner = safeMgr.isOwner(newOwner);

        // --- Apply on current fork (simulation) via vm.prank ---
        if (!alreadyOwner) {
            vm.prank(safe);
            safeMgr.addOwnerWithThreshold(newOwner, 1);
        } else {
            vm.prank(safe);
            safeMgr.changeThreshold(1);
        }

        for (uint256 i = 0; i < currentOwners.length; i++) {
            if (currentOwners[i] == newOwner) continue;
            address prevOwner = _findPrevOwner(safe, currentOwners[i]);
            vm.prank(safe);
            safeMgr.removeOwner(prevOwner, currentOwners[i], 1);
        }

        // --- Replay on anvil node via RPC impersonation ---
        Anvil.setBalanceRpc(safe, 100 ether);

        if (!alreadyOwner) {
            Anvil.sendTransactionAs(safe, safe, abi.encodeCall(safeMgr.addOwnerWithThreshold, (newOwner, 1)));
        } else {
            Anvil.sendTransactionAs(safe, safe, abi.encodeCall(safeMgr.changeThreshold, (1)));
        }

        // After addOwnerWithThreshold, newOwner is prepended: [newOwner, ...currentOwners].
        // Each removal shifts the list so newOwner always points to the next one.
        for (uint256 i = 0; i < currentOwners.length; i++) {
            if (currentOwners[i] == newOwner) continue;
            Anvil.sendTransactionAs(safe, safe, abi.encodeCall(safeMgr.removeOwner, (newOwner, currentOwners[i], 1)));
        }
    }

    function _findPrevOwner(address safe, address owner) internal view returns (address) {
        address[] memory owners = ISafeOwnerMgr(safe).getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                return i == 0 ? SENTINEL_OWNERS : owners[i - 1];
            }
        }
        revert("owner not found in safe");
    }

    /// @dev Write directly to MockCELO storage on Anvil.
    ///      balances mapping at slot 0: key slot = keccak256(abi.encode(account, 0))
    ///      totalSupply at slot 2.
    function _mintCELO(address to, uint256 amount) internal {
        bytes32 balanceSlot = keccak256(abi.encode(to, BALANCES_SLOT));
        Anvil.setStorageAt(CELO, balanceSlot, bytes32(amount));
        Anvil.setStorageAt(CELO, bytes32(TOTAL_SUPPLY_SLOT), bytes32(amount));
    }
}
