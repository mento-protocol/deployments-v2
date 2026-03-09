// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";

contract DeployReserve is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address reserveImpl;
    address reserveProxy;

    /// @custom:senders deployer
    function run() public broadcast {
        // Get configuration
        IMentoConfig config = Config.get();

        // Get the sender
        Senders.Sender storage deployer = sender("deployer");

        // Step 1: Deploy Reserve implementation (0.5.13)
        reserveImpl = deployer.create3("Reserve").setLabel("v2.6.5").deploy(abi.encode(false)); // test parameter
        console.log("Reserve implementation deployed at:", reserveImpl);

        // Step 2: Deploy proxy without initialization (to avoid msg.sender issues)
        reserveProxy = deployProxy(deployer, "Reserve", reserveImpl, "");
        console.log("Reserve proxy deployed at:", reserveProxy);

        // Step 3: Initialize the Reserve proxy (separate transaction to preserve msg.sender)
        initializeReserve(deployer, config);
    }

    /**
     * @notice Initialize Reserve with parameters from config
     */
    function initializeReserve(Senders.Sender storage deployer, IMentoConfig config) internal {
        // Get configuration
        IMentoConfig.ReserveConfig memory reserveConfig = config.getReserveConfig();
        address[] memory collateralAssets = config.getCollateralAssets();

        // Initialize through harness to preserve proper msg.sender
        IReserve reserve = IReserve(deployer.harness(reserveProxy));
        reserve.initialize(
            address(0x1), // registryAddress (to be set later)
            reserveConfig.tobinTaxStalenessThreshold,
            reserveConfig.spendingRatio,
            reserveConfig.frozenGold,
            reserveConfig.frozenDays,
            reserveConfig.assetAllocationSymbols,
            reserveConfig.assetAllocationWeights,
            reserveConfig.tobinTax,
            reserveConfig.tobinTaxReserveRatio,
            collateralAssets,
            reserveConfig.collateralAssetDailySpendingRatios
        );
        reserve.addExchangeSpender(predictProxy(deployer, "Broker"));

        console.log("Reserve initialized with config");
    }
}
