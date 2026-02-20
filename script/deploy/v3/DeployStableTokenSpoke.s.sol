// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";

import {IStableTokenSpoke} from "mento-core/interfaces/IStableTokenSpoke.sol";
import {StableTokenSpoke} from "mento-core/tokens/StableTokenSpoke.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ProxyAdmin} from "lib/mento-core/lib/openzeppelin-contracts-next/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentProxy} from "mento-core/interfaces/ITransparentProxy.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/mento-core/lib/openzeppelin-contracts-next/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IProxyAdmin {
    function transferOwnership(address newOwner) external;
    function upgradeAndCall(ITransparentUpgradeableProxy proxy, address implementation, bytes memory data)
        external
        payable;
}

contract DeployStableTokenSpoke is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address public constant MIGRATION_MULTISIG = 0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458;

    string label;
    string tokenName;
    string tokenSymbol;

    function setUp() public {
        label = vm.envString("SPOKE_LABEL");
        tokenName = vm.envString("SPOKE_TOKEN_NAME");
        tokenSymbol = vm.envString("SPOKE_TOKEN_SYMBOL");

        require(bytes(label).length > 0, "SPOKE_LABEL env var is empty");
        require(bytes(tokenName).length > 0, "SPOKE_TOKEN_NAME env var is empty");
        require(bytes(tokenSymbol).length > 0, "SPOKE_TOKEN_SYMBOL env var is empty");
    }

    /// @custom:senders deployer
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");

        address stableTokenSpokeImpl = lookup("StableTokenSpoke:v3.0.0");
        if (stableTokenSpokeImpl == address(0)) {
            console.log("StableTokenSpoke implementation not found, deploying...");
            stableTokenSpokeImpl = deployer.create3("StableTokenSpoke").setLabel("v3.0.0").deploy(abi.encode(true));
        }

        address[] memory initialBalanceAddresses = new address[](0);
        uint256[] memory initialBalanceValues = new uint256[](0);
        address[] memory minters = new address[](0);
        address[] memory burners = new address[](0);

        address initialOwner = MIGRATION_MULTISIG;
        address stableTokenSpokeProxy = deployOztupProxy(
            deployer,
            label,
            stableTokenSpokeImpl,
            abi.encodeWithSelector(
                IStableTokenSpoke.initialize.selector,
                tokenName,
                tokenSymbol,
                initialOwner,
                initialBalanceAddresses,
                initialBalanceValues,
                minters,
                burners
            )
        );
        IProxyAdmin(deployer.harness(getProxyAdmin(stableTokenSpokeProxy))).transferOwnership(MIGRATION_MULTISIG);

        // ====== Deployment checks ======
        console.log("\n sanity checks");
        string memory name = IERC20(stableTokenSpokeProxy).name();
        string memory symbol = IERC20(stableTokenSpokeProxy).symbol();

        console.log(" > name:", name);
        console.log(" > symbol: ", symbol);

        address proxyAdmin = getProxyAdmin(stableTokenSpokeProxy);
        address proxyAdminOwner = IOwnable(proxyAdmin).owner();
        require(IOwnable(proxyAdmin).owner() == MIGRATION_MULTISIG, "migration multisig should own the proxy admin");
        console.log(" > proxy admin: %s (owner: %s)", address(proxyAdmin), proxyAdminOwner);

        address proxyOwner = IOwnable(stableTokenSpokeProxy).owner();
        require(proxyOwner == MIGRATION_MULTISIG, "migration multisig should own the proxy");
        console.log(" > proxy: %s (owner: %s)", address(stableTokenSpokeProxy), proxyOwner);

        address proxyImplementation = getOZTUPProxyImplementation(stableTokenSpokeProxy);
        require(proxyImplementation == stableTokenSpokeImpl, "Unexpected proxy implementation");
        console.log(" > implementation: %s", address(proxyImplementation));

        require(IERC20(stableTokenSpokeProxy).totalSupply() == 0, "Total supply should be 0");

        console.log("\n permissions checks");
        checkMultisigCanSetRoles(stableTokenSpokeProxy);
        checkMultisigCanUpgradeProxy(stableTokenSpokeProxy);
    }

    function checkMultisigCanSetRoles(address stableTokenSpokeProxy) internal {
        address newMinter = address(1337);
        address newBurner = address(1338);

        require(!IStableTokenSpoke(stableTokenSpokeProxy).isMinter(newMinter), "minter already set");
        require(!IStableTokenSpoke(stableTokenSpokeProxy).isBurner(newBurner), "burner already set");

        vm.startPrank(MIGRATION_MULTISIG);
        IStableTokenSpoke(stableTokenSpokeProxy).setMinter(newMinter, true);
        IStableTokenSpoke(stableTokenSpokeProxy).setBurner(newBurner, true);
        vm.stopPrank();

        require(IStableTokenSpoke(stableTokenSpokeProxy).isMinter(newMinter), "minter not set");
        require(IStableTokenSpoke(stableTokenSpokeProxy).isBurner(newBurner), "burner not set");

        console.log(unicode" > multisig can set minter and burner ✅");

    }

    function checkMultisigCanUpgradeProxy(address stableTokenSpokeProxy) internal {
        address proxyAdmin = getProxyAdmin(stableTokenSpokeProxy);

        address newImpl = address(new StableTokenSpoke(true));

        vm.prank(MIGRATION_MULTISIG);
        IProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(stableTokenSpokeProxy),
            newImpl,
            abi.encodeWithSelector(IOwnable.owner.selector)
        );

        require(getOZTUPProxyImplementation(stableTokenSpokeProxy) == newImpl, "expected new implementation");

        console.log(unicode" > multisig can upgrade proxy implementation ✅");
    }
}
