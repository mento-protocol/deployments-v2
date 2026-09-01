// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IVirtualPoolFactory} from "lib/mento-core/contracts/interfaces/IVirtualPoolFactory.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/// @dev VirtualPool does not expose its exchangeId, only its token pair.
interface IVirtualPoolView {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/**
 * @title PrintVirtualPools
 * @notice Read-only: prints every active VirtualPool on the VirtualPoolFactory with its assets
 *         and status, cross-referenced by assets against the BiPoolManager's live exchanges to
 *         show the associated exchangeId.
 */
contract PrintVirtualPools is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        address factory = lookup("VirtualPoolFactory:v3.0.0");
        if (factory == address(0)) {
            console.log("No VirtualPoolFactory deployed on this network.");
            return;
        }

        address biPoolManager = lookupProxyOrFail("BiPoolManager");
        address[] memory pools = IVirtualPoolFactory(factory).getAllPools();

        console.log("Virtual pools on VirtualPoolFactory:", vm.toString(factory));
        console.log(string.concat(_padRight("pool", 44), _padRight("pair", 16), _padRight("status", 12), "exchangeId"));
        for (uint256 i = 0; i < pools.length; i++) {
            address token0 = IVirtualPoolView(pools[i]).token0();
            address token1 = IVirtualPoolView(pools[i]).token1();
            (bytes32 exchangeId, bool live) = _findLiveExchange(biPoolManager, token0, token1);

            console.log(
                string.concat(
                    _padRight(vm.toString(pools[i]), 44),
                    _padRight(string.concat(IERC20Metadata(token0).symbol(), "/", IERC20Metadata(token1).symbol()), 16),
                    _padRight(IVirtualPoolFactory(factory).isPoolDeprecated(pools[i]) ? "deprecated" : "active", 12),
                    live ? vm.toString(exchangeId) : "no live exchange"
                )
            );
        }
        console.log("Total:", pools.length);
    }

    function _padRight(string memory value, uint256 width) internal pure returns (string memory) {
        while (bytes(value).length < width) {
            value = string.concat(value, " ");
        }
        return value;
    }

    function _findLiveExchange(address biPoolManager, address token0, address token1)
        internal
        view
        returns (bytes32 exchangeId, bool live)
    {
        bytes32[] memory ids = IBiPoolManager(biPoolManager).getExchangeIds();
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(ids[i]);
            bool assetsMatch =
                (pool.asset0 == token0 && pool.asset1 == token1) || (pool.asset0 == token1 && pool.asset1 == token0);
            if (assetsMatch) {
                return (ids[i], true);
            }
        }
    }
}
