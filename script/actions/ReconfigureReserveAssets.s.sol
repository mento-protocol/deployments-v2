// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {IPricingModule} from "lib/mento-core/contracts/interfaces/IPricingModule.sol";

import {FixidityLib} from "@celo/common/FixidityLib.sol";

import {Config, IMentoConfig} from "../config/Config.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract ReconfigureReserveAssets is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    mapping(address => bool) collateralExistsInConfig;
    mapping(address => bool) stableExistsInConfig;

    address[] stableTokensToAdd;
    address[] collateralTokensToAdd;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();

        Senders.Sender storage deployer = sender("deployer");
        address reserveAddy = lookupProxyOrFail("Reserve");
        IReserve reserveWrite = IReserve(deployer.harness(reserveAddy));
        IReserve reserveRead = IReserve(reserveAddy);

        address[] memory reserveTokens = reserveRead.getTokens();
        address[] memory reserveCollateral = getCollateralAssets(reserveRead);

        IMentoConfig.TokenConfig[] memory tokens = config.getTokenConfigs();
        for (uint i = 0; i < tokens.length; i++) {
            IMentoConfig.TokenConfig memory token = tokens[i];
            address tokenAddy = lookupProxy(token.symbol);
            stableExistsInConfig[tokenAddy] = true;
            if (reserveRead.isStableAsset(tokenAddy)) continue;
            stableTokensToAdd.push(tokenAddy);
        }

        for (uint i = reserveTokens.length; i > 0; i--) {
            if (stableExistsInConfig[reserveTokens[i - 1]]) continue;
            reserveWrite.removeToken(reserveTokens[i - 1], i - 1);
            console.log("Removing Stable Token ", reserveTokens[i - 1]);
        }

        for (uint i = 0; i < stableTokensToAdd.length; i++) {
            reserveWrite.addToken(stableTokensToAdd[i]);
            console.log("Adding Stable Token ", stableTokensToAdd[i]);
        }

        address[] memory collaterals = config.getCollateralAssets();
        for (uint i = 0; i < collaterals.length; i++) {
            collateralExistsInConfig[collaterals[i]] = true;
            if (reserveRead.isCollateralAsset(collaterals[i])) continue;
            collateralTokensToAdd.push(collaterals[i]);
        }

        for (uint256 i = reserveCollateral.length; i > 0; i--) {
            if (collateralExistsInConfig[reserveCollateral[i - 1]]) continue;
            reserveWrite.removeCollateralAsset(reserveCollateral[i - 1], i - 1);
            console.log("Removing Collateral Token ", reserveTokens[i - 1]);
        }

        for (uint i = 0; i < collateralTokensToAdd.length; i++) {
            reserveWrite.addCollateralAsset(collateralTokensToAdd[i]);
            console.log("Adding Collateral Token ", collateralTokensToAdd[i]);
        }
    }

    function getCollateralAssets(
        IReserve reserve
    ) internal view returns (address[] memory) {
        uint256 len = getCollateralAssetsLength(reserve);
        address[] memory collaterals = new address[](len);
        for (uint i = 0; i < len; i++) {
            collaterals[i] = reserve.collateralAssets(i);
        }
        return collaterals;
    }

    function getCollateralAssetsLength(
        IReserve reserve
    ) internal view returns (uint256) {
        uint256 i = 0;
        while (true) {
            try reserve.collateralAssets(i) returns (address) {
                i++;
                continue;
            } catch {
                return i;
            }
        }
        revert("Unexpected");
    }
}
