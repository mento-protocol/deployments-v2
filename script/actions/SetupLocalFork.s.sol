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

contract SetupLocalFork is ForkHelper, Script {
    uint256 private constant BALANCES_SLOT = 0;
    uint256 private constant TOTAL_SUPPLY_SLOT = 2;
    uint256 private constant MINT_AMOUNT = 10_000_000 ether;

    function run() public {
        // 1. Convert Safe to single-owner for fork testing
        // convertSafeToSingleOwner(SAFE, PROPOSER);

        // 2. Etch no-op transfer precompile (safety net)
        // CeloTransferPrecompile precompileHandler = new CeloTransferPrecompile();
        // Anvil.setCodeRpc(TRANSFER_PRECOMPILE, address(precompileHandler).code);

        // 3. Replace GoldToken with standard ERC20 at CELO address
        MockCELO mock = new MockCELO();
        Anvil.setCodeRpc(CELO, address(mock).code);

        // 4. Mint CELO to deployer via direct storage writes
        _mintCELO(PROPOSER, MINT_AMOUNT);
        _mintCELO(DEPLOYER, MINT_AMOUNT);

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

    /// @dev Write directly to MockCELO storage on Anvil.
    ///      balances mapping at slot 0: key slot = keccak256(abi.encode(account, 0))
    ///      totalSupply at slot 2.
    function _mintCELO(address to, uint256 amount) internal {
        bytes32 balanceSlot = keccak256(abi.encode(to, BALANCES_SLOT));
        Anvil.setStorageAt(CELO, balanceSlot, bytes32(amount));
        Anvil.setStorageAt(CELO, bytes32(TOTAL_SUPPLY_SLOT), bytes32(amount));
    }
}
