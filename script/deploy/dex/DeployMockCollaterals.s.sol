// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";

import {MockERC20} from "src/MockERC20.sol";

contract DeployMockCollaterals is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        IMentoConfig config = Config.get();
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage migrationOwner = sender("migrationOwner");

        string[] memory mocks = config.getMockCollaterals();

        for (uint256 i = 0; i < mocks.length; i++) {
            string memory symbol = mocks[i];
            console.log("Symbol", symbol);
            address addy = deployer.create3("MockERC20").setLabel(symbol)
                .deploy(
                    abi.encode(
                        string.concat("Mento Mock ", symbol), symbol, config.getTokenDecimals(symbol), deployer.account
                    )
                );
            MockERC20 coll = MockERC20(deployer.harness(addy));
            coll.mint(deployer.account, 1000000e18);
            IOwnable(address(coll)).transferOwnership(address(migrationOwner.account));
        }
    }
}
