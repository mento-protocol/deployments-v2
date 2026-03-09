// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {Config, IMentoConfig} from "script/config/Config.sol";
import {IRPool} from "mento-core/swap/router/interfaces/IRPool.sol";
import {IRPoolFactory} from "mento-core/swap/router/interfaces/IRPoolFactory.sol";
import {IVirtualPoolFactory} from "mento-core/interfaces/IVirtualPoolFactory.sol";
import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IFactoryRegistry} from "mento-core/interfaces/IFactoryRegistry.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployVirtualPools is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    string constant label = "v3.0.0";
    IMentoConfig config;
    address virtualPoolFactory;
    address exchangeProvider;
    address factoryRegistry;

    function setUp() public {
        config = Config.get();
        exchangeProvider = lookupProxyOrFail("BiPoolManager");
        exchangeProvider = lookupProxyOrFail("FactoryRegistry");
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage owner = sender("migrationOwner");
        Senders.Sender storage deployer = sender("deployer");

        virtualPoolFactory = deployer.create3("VirtualPoolFactory").setLabel(label).deploy(abi.encode(owner.account));
        IFactoryRegistry factoryRegistryHarness = IFactoryRegistry(owner.harness(factoryRegistry));

        IVirtualPoolFactory factory = IVirtualPoolFactory(owner.harness(virtualPoolFactory));
        factoryRegistryHarness.approve(virtualPoolFactory);

        bytes32[] memory exchangeIds = IBiPoolManager(exchangeProvider).getExchangeIds();
        uint256 deployed;

        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory pool = IBiPoolManager(exchangeProvider).getPoolExchange(exchangeIds[i]);

            (IMentoConfig.ExchangeConfig memory exchangeConfig, bool found) =
                config.getExchangeConfig(pool.asset0, pool.asset1, address(pool.pricingModule));

            string memory name =
                string.concat(IERC20Metadata(pool.asset0).symbol(), "/", IERC20Metadata(pool.asset1).symbol());

            if (!found || !exchangeConfig.createVirtual) {
                continue;
            }

            // Skip if virtual pool already exists for this pair
            address existing = IRPoolFactory(virtualPoolFactory).getPool(pool.asset0, pool.asset1);
            if (existing != address(0)) {
                console.log(
                    string.concat(" > Skipping ", name, ": virtual pool already exists at ", vm.toString(existing))
                );
                continue;
            }

            console.log(string.concat(" > Deploying virtual pool for ", name));
            address virtualPool = factory.deployVirtualPool(exchangeProvider, exchangeIds[i]);
            console.log(string.concat("   deployed at ", vm.toString(virtualPool)));
            deployed++;

            // Post-check: verify tokens match
            (address token0, address token1) = IRPool(virtualPool).tokens();
            (address lowAsset, address highAsset) = _sortTokens(pool.asset0, pool.asset1);
            require(token0 == lowAsset && token1 == highAsset, string.concat("Token mismatch for ", name));
        }

        console.log(string.concat("\n Deployed ", vm.toString(deployed), " virtual pool(s)"));
    }

    function _sortTokens(address a, address b) internal pure returns (address, address) {
        return (a > b) ? (b, a) : (a, b);
    }
}
