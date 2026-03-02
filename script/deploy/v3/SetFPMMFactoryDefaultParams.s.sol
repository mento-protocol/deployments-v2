// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";

contract SetFPMMFactoryDefaultParams is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address fpmmFactory;
    address feeSetter;
    address protocolFeeRecipient;

    function setUp() public {
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        feeSetter = lookupOrFail("FeeSetter");
        protocolFeeRecipient = lookupOrFail("ProtocolFeeRecipient");
    }

    /// @custom:senders migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");

        IFPMM.FPMMParams memory params = IFPMM.FPMMParams({
            lpFee: 3,
            protocolFee: 2,
            protocolFeeRecipient: protocolFeeRecipient,
            feeSetter: feeSetter,
            rebalanceIncentive: 1,
            rebalanceThresholdAbove: 5000,
            rebalanceThresholdBelow: 3333
        });

        IFPMMFactory(owner.harness(fpmmFactory)).setDefaultParams(params);

        // Verify
        IFPMM.FPMMParams memory actual = IFPMMFactory(fpmmFactory).defaultParams();
        require(actual.lpFee == 3, "lpFee mismatch");
        require(actual.protocolFee == 2, "protocolFee mismatch");
        require(actual.protocolFeeRecipient == lookupOrFail("ProtocolFeeRecipient"), "protocolFeeRecipient mismatch");
        require(actual.feeSetter == lookupOrFail("FeeSetter"), "feeSetter mismatch");
        require(actual.rebalanceIncentive == 1, "rebalanceIncentive mismatch");
        require(actual.rebalanceThresholdAbove == 5000, "rebalanceThresholdAbove mismatch");
        require(actual.rebalanceThresholdBelow == 3333, "rebalanceThresholdBelow mismatch");
    }
}
