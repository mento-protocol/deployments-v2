// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IBreakerBox} from "mento-core/interfaces/IBreakerBox.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";

/// @title SwitchMarketHoursBreaker
/// @notice Deploys MarketHoursBreakerToggleable (if not yet deployed) and
///         replaces MarketHoursBreaker with it in BreakerBox & OracleAdapter.
contract SwitchMarketHoursBreaker is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    string constant label = "v3.0.0";

    IMentoConfig config;
    address breakerBox;
    address oracleAdapter;
    address[] fxFeedIds;
    address oldBreaker;
    address newBreaker;

    function setUp() public {
        config = Config.get();
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
        fxFeedIds = config.getFxRateFeedIds();

        oldBreaker = lookupOrFail("MarketHoursBreaker:v3.0.0");
        newBreaker = lookup("MarketHoursBreakerToggleable:v3.0.0");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage owner = sender("migrationOwner");

        // 1. Deploy MarketHoursBreakerToggleable if not yet deployed
        if (newBreaker == address(0)) {
            newBreaker =
                deployer.create3("MarketHoursBreakerToggleable").setLabel(label).deploy(abi.encode(deployer.account));
        }

        // 2. Switch in BreakerBox
        IBreakerBox bbWrite = IBreakerBox(owner.harness(breakerBox));
        IBreakerBox bbRead = IBreakerBox(breakerBox);

        // Disable old breaker on all FX feeds
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            if (bbRead.isBreakerEnabled(oldBreaker, fxFeedIds[i])) {
                bbWrite.toggleBreaker(oldBreaker, fxFeedIds[i], false);
            }
        }

        // Remove old breaker from BreakerBox
        if (bbRead.isBreaker(oldBreaker)) {
            bbWrite.removeBreaker(oldBreaker);
        }

        // Add new breaker with trading mode 3 (halted)
        if (!bbRead.isBreaker(newBreaker)) {
            bbWrite.addBreaker(newBreaker, 3);
        }

        // Enable new breaker on all FX feeds
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            if (!bbRead.isBreakerEnabled(newBreaker, fxFeedIds[i])) {
                bbWrite.toggleBreaker(newBreaker, fxFeedIds[i], true);
            }
        }

        // 3. Switch in OracleAdapter
        IOracleAdapter oaWrite = IOracleAdapter(owner.harness(oracleAdapter));
        oaWrite.setMarketHoursBreaker(newBreaker);

        postChecks();
    }

    function postChecks() internal view {
        IBreakerBox bbRead = IBreakerBox(breakerBox);
        IOracleAdapter oaRead = IOracleAdapter(oracleAdapter);

        // New breaker registered with correct trading mode
        require(bbRead.isBreaker(newBreaker), "New breaker not added to BreakerBox");
        require(bbRead.breakerTradingMode(newBreaker) == 3, "New breaker trading mode is not 3 (halted)");

        // New breaker enabled on all FX feeds
        for (uint256 i = 0; i < fxFeedIds.length; i++) {
            require(bbRead.isBreakerEnabled(newBreaker, fxFeedIds[i]), "New breaker not enabled for FX feed");
        }

        // Old breaker removed
        require(!bbRead.isBreaker(oldBreaker), "Old breaker still registered in BreakerBox");

        // OracleAdapter updated
        require(address(oaRead.marketHoursBreaker()) == newBreaker, "OracleAdapter marketHoursBreaker not updated");
    }
}
