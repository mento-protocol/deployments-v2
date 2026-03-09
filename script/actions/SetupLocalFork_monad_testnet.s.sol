// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Anvil} from "../helpers/Anvil.sol";
import {MockCELO} from "../helpers/MockCELO.sol";
import {SetupLocalFork, CELO} from "./SetupLocalFork.s.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IMockERC20 is IERC20 {
    function mint(address to, uint256 value) external;

    function burn(address from, uint256 value) external;
}

contract SetupLocalFork_monad_testnet is TrebScript, ProxyHelper, SetupLocalFork, StdCheats {
    using Senders for Senders.Sender;

    /// @custom:senders deployer, migrationOwner
    function run() public override broadcast {
        Senders.Sender storage _deployer = sender("deployer");
        Senders.Sender storage _migrationOwner = sender("migrationOwner");

        IStableTokenV3 gbpm = IStableTokenV3(_migrationOwner.harness(lookupProxy("GBPm", ProxyType.OZTUP)));
        IStableTokenV3 usdm = IStableTokenV3(_migrationOwner.harness(lookupProxy("USDm", ProxyType.OZTUP)));
        IMockERC20 ausd = IMockERC20(_migrationOwner.harness(lookup("MockERC20:AUSD")));
        ausd.mint(_migrationOwner.account, MINT_AMOUNT);
        gbpm.setMinter(_deployer.account, true);
        gbpm.mint(_migrationOwner.account, MINT_AMOUNT);
        usdm.setMinter(_deployer.account, true);
        usdm.mint(_migrationOwner.account, MINT_AMOUNT);
    }
}
