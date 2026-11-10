// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";

/// @dev Minimal interfaces for the Broker's auto-generated public mapping getters.
interface IBrokerTradingLimits {
    function tradingLimitsConfig(bytes32 limitId)
        external
        view
        returns (uint32 timestep0, uint32 timestep1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags);

    function tradingLimitsState(bytes32 limitId)
        external
        view
        returns (uint32 lastUpdated0, uint32 lastUpdated1, int48 netflow0, int48 netflow1, int48 netflowGlobal);
}

/**
 * @title PrintV2TradingLimits
 * @notice Read-only: for every live v2 exchange pairing USDm with an FX stable (skipping the
 *         pairs marked for deprecation), prints the FX token's total supply and the current
 *         netflowGlobal and configured LG on both sides.
 */
contract PrintV2TradingLimits is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    /// @custom:senders deployer
    function run() public broadcast {
        address broker = lookupProxyOrFail("Broker");
        address biPoolManager = lookupProxyOrFail("BiPoolManager");
        address usdm = lookupProxyOrFail("USDm");

        console.log("Trading limits on Broker:", vm.toString(broker));

        bytes32[] memory ids = IBiPoolManager(biPoolManager).getExchangeIds();
        for (uint256 i = 0; i < ids.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManager).getPoolExchange(ids[i]);

            address fx;
            if (pool.asset0 == usdm) fx = pool.asset1;
            else if (pool.asset1 == usdm) fx = pool.asset0;
            else continue;

            string memory fxSymbol = IERC20Metadata(fx).symbol();
            if (isSkipped(fxSymbol)) continue;

            uint256 supply = IERC20Metadata(fx).totalSupply();
            (,,,, int48 fxNetflow) = IBrokerTradingLimits(broker).tradingLimitsState(ids[i] ^ toBytes32(fx));
            (,,,, int48 fxLG,) = IBrokerTradingLimits(broker).tradingLimitsConfig(ids[i] ^ toBytes32(fx));
            (,,,, int48 usdmNetflow) = IBrokerTradingLimits(broker).tradingLimitsState(ids[i] ^ toBytes32(usdm));
            (,,,, int48 usdmLG,) = IBrokerTradingLimits(broker).tradingLimitsConfig(ids[i] ^ toBytes32(usdm));

            console.log(string.concat("\nExchange (USDm/", fxSymbol, ")"));
            console.log(string.concat("   ", fxSymbol, " supply:            ", groupDigits(supply / 1e18)));
            console.log(string.concat("   ", fxSymbol, " netflowGlobal:     ", formatSigned(fxNetflow)));
            console.log(string.concat("   ", fxSymbol, " current LG:        ", formatSigned(fxLG)));
            console.log(string.concat("   USDm netflowGlobal:     ", formatSigned(usdmNetflow)));
            console.log(string.concat("   USDm current LG:        ", formatSigned(usdmLG)));
        }
    }

    function isSkipped(string memory symbol) internal pure returns (bool) {
        bytes32 h = keccak256(bytes(symbol));
        return h == keccak256("CELO") || h == keccak256("axlUSDC") || h == keccak256("USDC") || h == keccak256("USDT")
            || h == keccak256(unicode"USD₮") || h == keccak256("EURm") || h == keccak256("axlEUROC");
    }

    function toBytes32(address token) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(token)));
    }

    function formatSigned(int256 value) internal pure returns (string memory) {
        if (value < 0) return string.concat("-", groupDigits(uint256(-value)));
        return groupDigits(uint256(value));
    }

    /// @dev Formats a number with `_` thousands separators, e.g. 1000000 -> "1_000_000".
    function groupDigits(uint256 value) internal pure returns (string memory) {
        bytes memory digits = bytes(vm.toString(value));
        if (digits.length <= 3) return string(digits);

        bytes memory out = new bytes(digits.length + (digits.length - 1) / 3);
        uint256 j = out.length;
        for (uint256 i = 0; i < digits.length; i++) {
            if (i > 0 && i % 3 == 0) out[--j] = "_";
            out[--j] = digits[digits.length - 1 - i];
        }
        return string(out);
    }
}
