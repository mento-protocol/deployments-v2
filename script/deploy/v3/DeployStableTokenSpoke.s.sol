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

    // address multisig;

    address stableTokenSpokeImpl;
    address stableTokenSpoke;

    string label = "v3.0.0";

    function setUp() public {
        // multisig = sender("multisig").account;
    }

    /// @custom:senders deployer
    function run() public broadcast {
        setUp();

        // Senders.Sender storage deployer = sender("multisig");
        Senders.Sender storage deployer = sender("deployer");
        address accnt = deployer.account;
        console.log("Deployer account:", accnt);

        // Deploy implementation with initializers disabled
        stableTokenSpokeImpl = deployer
            .create3("StableTokenSpoke")
            .setLabel(label)
            .deploy(abi.encode(true));

        // Deploy proxy with initialization
        // TODO: Set token name, symbol, minters, and burners as needed
        address[] memory initialBalanceAddresses = new address[](1);
        initialBalanceAddresses[0] = accnt;
        uint256[] memory initialBalanceValues = new uint256[](1);
        initialBalanceValues[0] = 1_000_000e18;
        address[] memory minters = new address[](1);
        minters[0] = accnt;
        address[] memory burners = new address[](0);

        stableTokenSpoke = deployProxy(
            deployer,
            "StableTokenSpoke",
            stableTokenSpokeImpl,
            abi.encodeWithSelector(
                IStableTokenSpoke.initialize.selector,
                "Stable Token Spoke Test",
                "sSPOKETEST",
                initialBalanceAddresses,
                initialBalanceValues,
                minters,
                burners
            )
        );

        // IStableTokenSpoke(deployer.harness(stableTokenSpoke)).setMinter(accnt, true);
        require(StableTokenSpoke(stableTokenSpoke).isMinter(accnt), "Deployer is not a minter");
        require(StableTokenSpoke(stableTokenSpoke).balanceOf(accnt) == 1_000_000e18, "Deployer does not have the correct balance");



        // postChecks();
    }


    function postChecks() internal view {
        // Proxy Implementation Check
        // verifyProxyImpl(
        //     "StableTokenSpoke",
        //     stableTokenSpoke,
        //     stableTokenSpokeImpl
        // );

        // // Proxy Admin Check
        // verifyProxyAdmin("StableTokenSpoke", stableTokenSpoke, multisig);

        // // Ownership Check
        // verifyOwnership("StableTokenSpoke", stableTokenSpoke, multisig);

        // // Implementation Initializer Protection
        // verifyInitDisabled("StableTokenSpokeImpl", stableTokenSpokeImpl);
    }

}
