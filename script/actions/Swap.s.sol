// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBroker} from "lib/mento-core/contracts/interfaces/IBroker.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

contract Swap is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;

    /// @custom:env {string} from
    /// @custom:env {string} to
    /// @custom:env {uint256} amountInUnits
    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        config = Config.get();
        Senders.Sender storage deployer = sender("deployer");
        address biPoolAddy = lookupProxyOrFail("BiPoolManager");
        address brokerAddy = lookupProxyOrFail("Broker");
        address fromAddy = config.getAddress(vm.envString("from"));
        address toAddy = config.getAddress(vm.envString("to"));
        uint256 amountInUnits = vm.envUint("amountInUnits");
        bytes32 exchangeId = config.getExchangeId(fromAddy, toAddy);

        IERC20Metadata from = IERC20Metadata(deployer.harness(fromAddy));
        uint256 amountIn = amountInUnits * 10 ** from.decimals();
        from.approve(brokerAddy, amountIn);

        IBroker broker = IBroker(deployer.harness(brokerAddy));
        broker.swapIn(biPoolAddy, exchangeId, fromAddy, toAddy, amountIn, 0);
    }
}
