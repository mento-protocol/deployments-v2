// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {ForkHelper, ISafeOwnerManager} from "lib/treb-sol/src/ForkHelper.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";

contract SetupLocalFork_celo is TrebScript, ForkHelper {
    using Senders for Senders.Sender;

    address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    uint256 private constant BALANCES_SLOT = 0;
    uint256 private constant TOTAL_SUPPLY_SLOT = 2;
    uint256 private constant MINT_AMOUNT = 10_000_000 ether;

    /// @custom:senders signer, deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage _signer = sender("signer");
        Senders.Sender storage _deployer = sender("deployer");
        Senders.Sender storage _migrationOwner = sender("migrationOwner");

        // 1. Convert Safe senders to 1/1 with signer as the sole owner
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

        convertSafeToSingleOwner(_sender.account, _signerAddr);

        console.log(string.concat("Converted ", label, " safe to 1/1:"));
        console.log("  safe:", _sender.account);
        console.log("  threshold:", ISafeOwnerManager(_sender.account).getThreshold());
        console.log("  signer is owner:", ISafeOwnerManager(_sender.account).isOwner(_signerAddr));
    }

    function _mintCELO(address to, uint256 amount) internal {
        bytes32 balanceSlot = keccak256(abi.encode(to, BALANCES_SLOT));
        Anvil.setStorageAt(CELO, balanceSlot, bytes32(amount));
        Anvil.setStorageAt(CELO, bytes32(TOTAL_SUPPLY_SLOT), bytes32(amount));
    }
}
