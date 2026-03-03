// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage} from "forge-std/StdStorage.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SetupLocalFork, ISafeOwnerMgr, CELO} from "./SetupLocalFork.s.sol";

contract SetupLocalFork_celo is TrebScript, SetupLocalFork {
    using Senders for Senders.Sender;
    using stdStorage for StdStorage;

    // Token addresses on Celo mainnet
    address constant USDm = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant EURm = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address constant GBPm = 0xCCF663b1fF11028f0b19058d0f7B674004a40746;
    address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address constant axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

    /// @custom:senders signer, deployer, migrationOwner
    function run() public override broadcast {
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
