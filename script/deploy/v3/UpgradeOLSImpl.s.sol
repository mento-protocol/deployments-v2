// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/mento-core/lib/openzeppelin-contracts-next/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IProxyAdmin {
    function upgradeAndCall(ITransparentUpgradeableProxy proxy, address implementation, bytes memory data)
        external
        payable;
}

contract UpgradeOLSImpl is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address olsProxy;

    string constant NEW_LABEL = "v3.0.1";

    function setUp() public {
        olsProxy = lookupProxyOrFail("OpenLiquidityStrategy");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage owner = sender("migrationOwner");

        // 1. Deploy new implementation
        address newImpl = deployer.create3("OpenLiquidityStrategy").setLabel(NEW_LABEL).deploy(abi.encode(true)); // constructor(bool disable)

        // 2. Get the ProxyAdmin that governs this proxy (ERC-1967 admin slot)
        address proxyAdmin = getProxyAdmin(olsProxy);

        // 3. Upgrade via ProxyAdmin (owner must be ProxyAdmin's owner)
        IProxyAdmin(owner.harness(proxyAdmin))
            .upgradeAndCall(
                ITransparentUpgradeableProxy(olsProxy),
                newImpl,
                "" // no re-initialization needed
            );

        // 4. Verify
        verifyProxyImpl("OpenLiquidityStrategy", olsProxy, newImpl);
        verifyInitDisabled("OpenLiquidityStrategyImpl", newImpl);
    }
}
