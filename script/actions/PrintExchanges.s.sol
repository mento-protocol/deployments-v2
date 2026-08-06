// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/**
 * @title PrintExchanges
 * @notice Read-only: prints every live v2 exchange on the BiPoolManager with its assets and id.
 */
contract PrintExchanges is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        address biPoolManager = lookupProxyOrFail("BiPoolManager");
        bytes32[] memory ids = IBiPoolManager(biPoolManager).getExchangeIds();

        console.log("Live v2 exchanges on BiPoolManager:", vm.toString(biPoolManager));
        console.log(string.concat(_padRight("index", 7), _padRight("pair", 16), "exchangeId"));
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(ids[i]);
            console.log(
                string.concat(
                    _padRight(vm.toString(i), 7),
                    _padRight(
                        string.concat(IERC20Metadata(pool.asset0).symbol(), "/", IERC20Metadata(pool.asset1).symbol()),
                        16
                    ),
                    vm.toString(ids[i])
                )
            );
        }
        console.log("Total:", ids.length);
    }

    function _padRight(string memory value, uint256 width) internal pure returns (string memory) {
        while (bytes(value).length < width) {
            value = string.concat(value, " ");
        }
        return value;
    }
}
