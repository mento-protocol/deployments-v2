// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {bytes32s, addresses} from "mento-std/Array.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {IReserve} from "lib/mento-core/contracts/interfaces/IReserve.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {ProxyHelper} from "../helpers/ProxyHelper.sol";

contract DeployBiPoolManager is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address biPoolManagerImpl;
    address biPoolManagerProxy;

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        biPoolManagerImpl = deployer
            .create3("BiPoolManager")
            .setLabel("v2.6.5")
            .deploy(abi.encode(false));

        biPoolManagerProxy = deployProxy(
            deployer,
            "BiPoolManager",
            biPoolManagerImpl,
            ""
        );

        address brokerProxy = lookupProxyOrFail("Broker");
        address reserveProxy = lookupProxyOrFail("Reserve");
        address sortedOraclesProxy = lookupProxyOrFail("SortedOracles");
        address breakerBoxProxy = lookupOrFail("BreakerBox:v2.6.5");

        IBiPoolManager biPoolManager = IBiPoolManager(
            deployer.harness(biPoolManagerProxy)
        );

        biPoolManager.initialize(
            brokerProxy,
            IReserve(reserveProxy),
            ISortedOracles(sortedOraclesProxy),
            IBreakerBox(breakerBoxProxy)
        );

        biPoolManager.setPricingModules(
            bytes32s(
                IBiPoolManager(biPoolManagerProxy).CONSTANT_SUM(),
                IBiPoolManager(biPoolManagerProxy).CONSTANT_PRODUCT()
            ),
            addresses(
                lookupOrFail("ConstantSumPricingModule:v2.6.5"),
                lookupOrFail("ConstantProductPricingModule:v2.6.5")
            )
        );
    }
}
