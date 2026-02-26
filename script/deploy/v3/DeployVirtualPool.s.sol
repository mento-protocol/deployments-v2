// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper, ProxyType} from "script/helpers/ProxyHelper.sol";
import {AddressbookHelper} from "script/helpers/AddressbookHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {IRPool} from "mento-core/swap/router/interfaces/IRPool.sol";
import {IVirtualPoolFactory} from "mento-core/interfaces/IVirtualPoolFactory.sol";
import {IBiPoolManager} from "mento-core/interfaces/IBiPoolManager.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployVirtualPool is
    TrebScript,
    AddressbookHelper,
    ProxyHelper,
    PostChecksHelper
{
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    address virtualPoolFactory;
    address virtualPool;
    address broker;
    IBiPoolManager.PoolExchange exchange;
    bytes32 exchangeId;
    address exchangeProvider;

    string constant label = "v3.0.0";

    function setUp() public {
        virtualPoolFactory = lookupOrFail("VirtualPoolFactory:v3.0.0");
        broker = lookupProxyOrFail("Broker", ProxyType.CELO);
        exchangeProvider = lookupProxyOrFail("BiPoolManager", ProxyType.CELO);
        string memory exchangeName = vm.envString("EXCHANGE_NAME");
        exchangeId = vm.envOr("EXCHANGE_ID", bytes32(0));
        bool exchangeNameSet = bytes(exchangeName).length > 0;
        bool exchangeIdSet = bytes32(exchangeId) != bytes32(0);
        require(
            (exchangeNameSet && !exchangeIdSet) ||
                (exchangeIdSet && !exchangeNameSet),
            "either EXCHANGE_NAME or EXCHANGE_ID env var should be provided (but not both)"
        );
        (exchangeId, exchange) = (exchangeNameSet)
            ? getExchange(exchangeName)
            : (
                exchangeId,
                IBiPoolManager(exchangeProvider).getPoolExchange(exchangeId)
            );
        require(exchangeId != bytes32(0), "Exchange doesn't seem to be valid");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        IVirtualPoolFactory virtualPoolFactoryHarness = IVirtualPoolFactory(
            deployer.harness(virtualPoolFactory)
        );

        virtualPool = virtualPoolFactoryHarness.deployVirtualPool(
            exchangeProvider,
            exchangeId
        );
        postChecks();
    }

    function postChecks() internal view {
        IRPool pool = IRPool(virtualPool);

        (address token0, address token1) = pool.tokens();
        (address lowAsset, address highAsset) = _sortTokens(
            exchange.asset0,
            exchange.asset1
        );
        require(
            token0 == lowAsset && token1 == highAsset,
            "Tokens in the virtual pool don't match the ones from the exchange"
        );
    }

    function _sortTokens(
        address a,
        address b
    ) internal pure returns (address, address) {
        return (a > b) ? (b, a) : (a, b);
    }

    function getExchange(
        string memory name
    ) internal view returns (bytes32, IBiPoolManager.PoolExchange memory) {
        bytes32 nameHash = keccak256(bytes(name));
        bytes32[] memory exchangeIds = IBiPoolManager(exchangeProvider)
            .getExchangeIds();
        for (uint256 i = 0; i < exchangeIds.length; i++) {
            IBiPoolManager.PoolExchange memory poolExchange = IBiPoolManager(
                exchangeProvider
            ).getPoolExchange(exchangeIds[i]);
            string memory asset0Symbol = IERC20Metadata(poolExchange.asset0)
                .symbol();
            string memory asset1Symbol = IERC20Metadata(poolExchange.asset1)
                .symbol();
            bytes32 zeroOne = keccak256(
                abi.encodePacked(asset0Symbol, "/", asset1Symbol)
            );
            bytes32 oneZero = keccak256(
                abi.encodePacked(asset1Symbol, "/", asset0Symbol)
            );
            if (zeroOne == nameHash || oneZero == nameHash) {
                return (exchangeIds[i], poolExchange);
            }
        }
        revert(string.concat("Could not find an exchange for ", name));
    }
}
