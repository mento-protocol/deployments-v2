// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IStableTokenV3} from "lib/mento-core/contracts/interfaces/IStableTokenV3.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract MintTestnetStable is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    uint256 constant CELO_SEPOLIA_CHAIN_ID = 11142220;
    uint256 constant MONAD_TESTNET_CHAIN_ID = 10143;

    /// @custom:senders deployer, migrationOwner
    /// @custom:env {string} token - Symbol of the token to mint (e.g. "JPYm")
    /// @custom:env {uint} balance - Amount to mint, in whole token units (decimals are applied by the script)
    function run() public broadcast {
        require(
            block.chainid == CELO_SEPOLIA_CHAIN_ID || block.chainid == MONAD_TESTNET_CHAIN_ID,
            "MintTestnetStable: only allowed on celo_sepolia or monad_testnet"
        );

        Senders.Sender storage owner = sender("migrationOwner");
        Senders.Sender storage deployer = sender("deployer");
        string memory tokenSymbol = vm.envString("token");
        uint256 balance = vm.envUint("balance");
        address tokenProxy = lookupProxyOrFail(tokenSymbol);

        IStableTokenV3 token = IStableTokenV3(tokenProxy);
        uint256 decimals = IERC20Metadata(tokenProxy).decimals();
        uint256 amount = balance * (10 ** decimals);

        console.log("\n===== Minting %s =====", tokenSymbol);
        console.log("  > proxy:", tokenProxy);
        console.log("  > to:", deployer.account);
        console.log("  > amount:", amount);

        uint256 balanceBefore = token.balanceOf(deployer.account);

        // 1. Grant minter role to migrationOwner
        IStableTokenV3(owner.harness(tokenProxy)).setMinter(owner.account, true);
        require(token.isMinter(owner.account), "Failed to grant minter role to migrationOwner");
        console.log("  > Granted minter to migrationOwner");

        // 2. Mint tokens to the deployer
        IStableTokenV3(owner.harness(tokenProxy)).mint(deployer.account, amount);
        console.log("  > Minted %s tokens to deployer", tokenSymbol);

        // 3. Remove minter role from migrationOwner
        IStableTokenV3(owner.harness(tokenProxy)).setMinter(owner.account, false);

        // 4. Verify minter role was revoked and recipient balance increased by the minted amount
        require(!token.isMinter(owner.account), "Failed to revoke minter role from migrationOwner");
        console.log("  > Revoked minter from migrationOwner");

        uint256 balanceAfter = token.balanceOf(deployer.account);
        require(balanceAfter == balanceBefore + amount, "Mint verification failed: deployer balance mismatch");
        console.log("  > Verified deployer balance: %s -> %s", balanceBefore, balanceAfter);
    }
}
