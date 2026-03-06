// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";

contract SetL2SequencerUptimeFeed is TrebScript, ProxyHelper {
    using Senders for Senders.Sender;

    address oracleAdapter;

    function setUp() public {
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");
        address l2SequencerUptimeFeed = lookup("L2SequencerUptimeFeed");

        if (address(IOracleAdapter(oracleAdapter).l2SequencerUptimeFeed()) == l2SequencerUptimeFeed) {
            console.log("L2 sequencer uptime feed already set to:", l2SequencerUptimeFeed);
            return;
        }

        IOracleAdapter oa = IOracleAdapter(owner.harness(oracleAdapter));
        oa.setL2SequencerUptimeFeed(l2SequencerUptimeFeed);

        // Verify
        address updated = address(IOracleAdapter(oracleAdapter).l2SequencerUptimeFeed());
        require(updated == l2SequencerUptimeFeed, "L2 sequencer uptime feed not set");
        require(IOracleAdapter(oracleAdapter).isL2SequencerUp(1 seconds) == true, "L2 sequencer is not up");
        console.log("Set L2 sequencer uptime feed to:", l2SequencerUptimeFeed);
    }
}
