// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";

import {IStableTokenV3} from "lib/mento-core/contracts/interfaces/IStableTokenV3.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract MintStableTokens is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    uint256 constant CELO_SEPOLIA_CHAIN_ID = 11142220;
    uint256 constant MONAD_TESTNET_CHAIN_ID = 10143;
    uint256 constant POLYGON_TESTNET_CHAIN_ID = 80002;
    uint256 constant MINT_AMOUNT = 1_000_000;

    /// @custom:senders deployer, migrationOwner
    /// @custom:env {string} token - Symbol of the token to mint (e.g. "USDm")
    function run() public broadcast {
        require(
            block.chainid == CELO_SEPOLIA_CHAIN_ID ||
            block.chainid == MONAD_TESTNET_CHAIN_ID ||
            block.chainid == POLYGON_TESTNET_CHAIN_ID,
            "MintStableTokens: only allowed to run on testnets"
        );

        Senders.Sender storage owner = sender("migrationOwner");
        string memory tokenSymbol = vm.envString("token");
        address tokenProxy = lookupProxyOrFail(tokenSymbol);

        _mintToken(owner, tokenProxy, tokenSymbol);
    }

    function _mintToken(Senders.Sender storage owner, address tokenProxy, string memory symbol) internal {
        IStableTokenV3 token = IStableTokenV3(tokenProxy);
        uint256 decimals = IERC20Metadata(tokenProxy).decimals();
        uint256 amount = MINT_AMOUNT * (10 ** decimals);

        console.log("\n===== Minting %s =====", symbol);
        console.log("  > proxy:", tokenProxy);
        console.log("  > amount:", amount);

        // 1. Grant minter role to migrationOwner
        IStableTokenV3(owner.harness(tokenProxy)).setMinter(owner.account, true);
        require(token.isMinter(owner.account), "Failed to grant minter role");
        console.log("  > Granted minter to migrationOwner");

        // 2. Mint tokens to migrationOwner
        IStableTokenV3(owner.harness(tokenProxy)).mint(owner.account, amount);
        console.log("  > Minted %s tokens to migrationOwner", symbol);

        // 3. Remove minter role from migrationOwner
        IStableTokenV3(owner.harness(tokenProxy)).setMinter(owner.account, false);
        require(!token.isMinter(owner.account), "Failed to revoke minter role");
        console.log("  > Revoked minter from migrationOwner");
    }
}
