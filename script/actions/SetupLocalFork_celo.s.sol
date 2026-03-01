// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {ForkHelper} from "lib/treb-sol/src/ForkHelper.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface ISafeOwnerMgr {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 _threshold) external;
    function changeThreshold(uint256 _threshold) external;
}

contract SetupLocalFork_celo is TrebScript, ForkHelper {
    using Senders for Senders.Sender;
    using stdStorage for StdStorage;

    address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    uint256 private constant BALANCES_SLOT = 0;
    uint256 private constant TOTAL_SUPPLY_SLOT = 2;
    uint256 private constant MINT_AMOUNT = 10_000_000 ether;

    address private constant SENTINEL_OWNERS = address(0x1);

    // Token addresses on Celo mainnet
    address constant USDm = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant EURm = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address constant GBPm = 0xCCF663b1fF11028f0b19058d0f7B674004a40746;
    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address constant axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

    /// @custom:senders signer, deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage _signer = sender("signer");
        Senders.Sender storage _deployer = sender("deployer");
        Senders.Sender storage _migrationOwner = sender("migrationOwner");

        // 1. Convert Safe senders to 1/1 with signer as the sole owner.
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

        // 4. Mint ERC20 tokens to migrationOwner safe
        address migrationOwner = _migrationOwner.account;
        _dealErc20(USDm, migrationOwner, 10 * 1e18);
        _dealErc20(EURm, migrationOwner, 10 * 1e18);
        _dealErc20(GBPm, migrationOwner, 10 * 1e18);
        _dealErc20(USDC, migrationOwner, 10 * 1e6);
        _dealErc20(USDT, migrationOwner, 10 * 1e6);
        _dealErc20(axlUSDC, migrationOwner, 10 * 1e6);

        console.log("ERC20 balances set for migrationOwner:", migrationOwner);
        console.log("  USDm:", IERC20(USDm).balanceOf(migrationOwner));
        console.log("  EURm:", IERC20(EURm).balanceOf(migrationOwner));
        console.log("  GBPm:", IERC20(GBPm).balanceOf(migrationOwner));
        console.log("  USDC:", IERC20(USDC).balanceOf(migrationOwner));
        console.log("  USDT:", IERC20(USDT).balanceOf(migrationOwner));
        console.log("  axlUSDC:", IERC20(axlUSDC).balanceOf(migrationOwner));
    }

    function _ensureSafeIs1of1(Senders.Sender storage _sender, address _signerAddr, string memory label) internal {
        if (!_sender.isType(SenderTypes.GnosisSafe)) return;

        _convertSafeToSingleOwner(_sender.account, _signerAddr);

        console.log(string.concat("Converted ", label, " safe to 1/1:"));
        console.log("  safe:", _sender.account);
        console.log("  threshold:", ISafeOwnerMgr(_sender.account).getThreshold());
        console.log("  signer is owner:", ISafeOwnerMgr(_sender.account).isOwner(_signerAddr));
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
        Anvil.impersonateAccount(safe);

        if (!alreadyOwner) {
            Anvil.sendTransaction(safe, safe, abi.encodeCall(safeMgr.addOwnerWithThreshold, (newOwner, 1)));
        } else {
            Anvil.sendTransaction(safe, safe, abi.encodeCall(safeMgr.changeThreshold, (1)));
        }

        // After addOwnerWithThreshold, newOwner is prepended: [newOwner, ...currentOwners].
        // Each removal shifts the list so newOwner always points to the next one.
        for (uint256 i = 0; i < currentOwners.length; i++) {
            if (currentOwners[i] == newOwner) continue;
            Anvil.sendTransaction(safe, safe, abi.encodeCall(safeMgr.removeOwner, (newOwner, currentOwners[i], 1)));
        }

        Anvil.stopImpersonatingAccount(safe);
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

    function _mintCELO(address to, uint256 amount) internal {
        bytes32 balanceSlot = keccak256(abi.encode(to, BALANCES_SLOT));
        Anvil.setStorageAt(CELO, balanceSlot, bytes32(amount));
        Anvil.setStorageAt(CELO, bytes32(TOTAL_SUPPLY_SLOT), bytes32(amount));
    }

    function _dealErc20(address token, address to, uint256 amount) internal {
        uint256 slot = stdstore
            .target(token)
            .sig(IERC20.balanceOf.selector)
            .with_key(to)
            .find();

        // Write to simulation fork
        vm.store(token, bytes32(slot), bytes32(amount));

        // Write to anvil node for cross-script persistence
        Anvil.setStorageAt(token, bytes32(slot), bytes32(amount));
    }
}
