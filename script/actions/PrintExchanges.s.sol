// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IExchangeProvider} from "mento-core/interfaces/IExchangeProvider.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/// @notice Debug script: prints all exchanges in the BiPoolManager with the
///         token symbols of each pair and the reference rate feed ID.
contract PrintExchanges is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address biPoolManager;

    function setUp() public {
        biPoolManager = lookupProxyOrFail("BiPoolManager");
    }

    /// @custom:senders deployer
    function run() public view {
        IBiPoolManager biPoolManagerRead = IBiPoolManager(biPoolManager);
        IExchangeProvider.Exchange[] memory exchanges = biPoolManagerRead.getExchanges();

        console.log("\n===== BiPoolManager exchanges =====");
        console.log("BiPoolManager:", biPoolManager);
        console.log("Exchange count:", exchanges.length);

        for (uint256 i = 0; i < exchanges.length; i++) {
            bytes32 exchangeId = exchanges[i].exchangeId;
            IBiPoolManager.PoolExchange memory pool = biPoolManagerRead.getPoolExchange(exchangeId);

            string memory symbol0 = _symbol(pool.asset0);
            string memory symbol1 = _symbol(pool.asset1);

            console.log("\n  [%s] %s/%s", i, symbol0, symbol1);
            console.log("    exchangeId:        ", vm.toString(exchangeId));
            console.log("    asset0:            ", pool.asset0);
            console.log("    asset1:            ", pool.asset1);
            console.log("    referenceRateFeedID:", pool.config.referenceRateFeedID);
        }

        console.log("\n  Printed %s exchange(s)", exchanges.length);
    }

    /// @dev Reads an ERC20 symbol, falling back to "?" if the call reverts.
    function _symbol(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return "?";
        }
    }
}
