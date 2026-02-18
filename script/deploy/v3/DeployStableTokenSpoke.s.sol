// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";
import {StableTokenSpoke} from "mento-core/tokens/StableTokenSpoke.sol";
import {console2 as console} from "forge-std/console2.sol";

contract DeployStableTokenSpoke is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    string label = "SpokeTestGBP";
    string tokenName = "StableTokenSpokeTestGBP";
    string tokenSymbol = "sSPOKETESTGBP";

    function setUp() public {
    }

    /// @custom:senders deployer
    function run() public broadcast {
        setUp();

        Senders.Sender storage deployer = sender("deployer");
        address deployerAccount = deployer.account;

        address stableTokenSpokeImpl = lookup("StableTokenSpoke:StableTokenSpokeImpl");
        if (stableTokenSpokeImpl == address(0)) {
            console.log("StableTokenSpokeImpl not deployed, deploying...");
            stableTokenSpokeImpl = deployer
                .create3("StableTokenSpoke")
                .setLabel("StableTokenSpokeImpl")
                .deploy(abi.encode(true));
        }

        // Deploy proxy with initialization
        address[] memory initialBalanceAddresses = new address[](1);
        initialBalanceAddresses[0] = deployerAccount;
        uint256[] memory initialBalanceValues = new uint256[](1);
        initialBalanceValues[0] = 1_000_000e18;
        address[] memory minters = new address[](1);
        minters[0] = deployerAccount;
        address[] memory burners = new address[](0);

        address stableTokenSpoke = deployProxy(
            deployer,
            label,
            stableTokenSpokeImpl,
            abi.encodeWithSelector(
                IStableTokenSpoke.initialize.selector,
                tokenName,
                tokenSymbol,
                initialBalanceAddresses,
                initialBalanceValues,
                minters,
                burners
            )
        );

        // IStableTokenSpoke(deployer.harness(stableTokenSpoke)).setMinter(accnt, true);
        require(StableTokenSpoke(stableTokenSpoke).isMinter(deployerAccount), "Deployer is not a minter");
        require(StableTokenSpoke(stableTokenSpoke).balanceOf(deployerAccount) == 1_000_000e18, "Deployer does not have the correct balance");

        string memory name = StableTokenSpoke(stableTokenSpoke).name();
        string memory symbol = StableTokenSpoke(stableTokenSpoke).symbol();
        address owner = StableTokenSpoke(stableTokenSpoke).owner();
        require(owner == deployerAccount, "Deployer is not the owner");


        console.log("\n");
        console.log("%s (%s)", name, symbol);
        console.log("proxy address at:", address(stableTokenSpoke));
        console.log("impl address at:", address(stableTokenSpokeImpl));
        console.log("owner: ", owner);
    }
}
