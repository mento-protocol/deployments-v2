// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IRouter} from "mento-core/swap/router/interfaces/IRouter.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

contract SwapVirtualPool is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    IMentoConfig config;
    address routerAddy;
    address virtualPoolFactory;
    address fromAddy;
    address toAddy;
    uint256 amountInUnits;

    function setUp() public {
        config = Config.get();
        routerAddy = lookupOrFail("Router:v3.0.0");
        virtualPoolFactory = lookupOrFail("VirtualPoolFactory:v3.0.0");
        fromAddy = config.getAddress(vm.envString("from"));
        toAddy = config.getAddress(vm.envString("to"));
        amountInUnits = vm.envUint("amountInUnits");
    }

    /// @custom:env {string} from
    /// @custom:env {string} to
    /// @custom:env {uint256} amountInUnits
    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        IERC20Metadata fromToken = IERC20Metadata(fromAddy);
        IERC20Metadata toToken = IERC20Metadata(toAddy);
        uint256 amountIn = amountInUnits * 10 ** fromToken.decimals();

        uint256 balanceBefore = toToken.balanceOf(deployer.account);

        IERC20Metadata(deployer.harness(fromAddy)).approve(routerAddy, amountIn);

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: fromAddy, to: toAddy, factory: virtualPoolFactory});

        IRouter(deployer.harness(routerAddy))
            .swapExactTokensForTokens(amountIn, 0, routes, deployer.account, block.timestamp);

        uint256 received = toToken.balanceOf(deployer.account) - balanceBefore;
        console.log(
            string.concat(
                " > Swapped ",
                vm.toString(amountInUnits),
                " ",
                fromToken.symbol(),
                " -> ",
                vm.toString(received),
                " ",
                toToken.symbol(),
                " (raw)"
            )
        );
    }
}
