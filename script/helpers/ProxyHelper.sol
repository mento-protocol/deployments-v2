// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

enum ProxyType {
    CELO, // Celo Legacy Proxy
    OZTUP // Open Zeppeling TransparentUpgradeableProxy
}

string constant CELO_LOOKUP_PREFIX = "Proxy:";
string constant OZTUP_LOOKUP_PREFIX = "TransparentUpgradeableProxy:";
string constant CELO_ARTIFACT = "src/Proxy.sol:Proxy";
string constant OZTUP_ARTIFACT = "TransparentUpgradeableProxy";

interface ILegacyProxy {
    function _setImplementation(address implementation) external;

    function _setAndInitializeImplementation(
        address implementation,
        bytes calldata init
    ) external;

    function _transferOwnership(address newOwner) external;
}

contract ProxyHelper is TrebScript {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    ProxyType immutable defaultProxyType;

    error InvalidProxyType(string);
    error UnsupportedProxyType(ProxyType);

    constructor() {
        string memory proxyTypeFromEnv = vm.envOr(
            "defaultProxyType",
            string("")
        );
        if (bytes(proxyTypeFromEnv).length > 0) {
            if (
                keccak256(bytes(vm.envString("defaultProxyType"))) ==
                keccak256("CELO")
            ) {
                defaultProxyType = ProxyType.CELO;
            } else if (
                keccak256(bytes(vm.envString("defaultProxyType"))) ==
                keccak256("OZTUP")
            ) {
                defaultProxyType = ProxyType.OZTUP;
            } else {
                revert InvalidProxyType(vm.envString("proxyType"));
            }
        } else {
            defaultProxyType = ProxyType.CELO;
        }
    }

    function lookupProxy(
        string memory contractName
    ) internal view returns (address proxy) {
        proxy = lookupProxy(contractName, defaultProxyType);
    }

    function lookupProxy(
        string memory contractName,
        ProxyType _proxyType
    ) internal view returns (address proxy) {
        string memory identifier;
        if (_proxyType == ProxyType.CELO) {
            identifier = string.concat(CELO_LOOKUP_PREFIX, contractName);
        } else if (_proxyType == ProxyType.OZTUP) {
            identifier = string.concat(OZTUP_LOOKUP_PREFIX, contractName);
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
        proxy = lookup(identifier);
    }

    function lookupProxyOrFail(
        string memory contractName
    ) internal view returns (address proxy) {
        proxy = lookupProxyOrFail(contractName, defaultProxyType);
    }

    function lookupProxyOrFail(
        string memory contractName,
        ProxyType _proxyType
    ) internal view returns (address proxy) {
        string memory identifier;
        if (_proxyType == ProxyType.CELO) {
            identifier = string.concat(CELO_LOOKUP_PREFIX, contractName);
        } else if (_proxyType == ProxyType.OZTUP) {
            identifier = string.concat(OZTUP_LOOKUP_PREFIX, contractName);
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
        proxy = lookupOrFail(identifier);
    }

    function lookupOrFail(
        string memory identifier
    ) internal view returns (address addy) {
        addy = lookup(identifier);
        require(addy != address(0), string.concat(identifier, " not deployed"));
    }

    function deployProxy(
        Senders.Sender storage deployer,
        string memory label,
        address implementation,
        bytes memory initData
    ) internal returns (address proxy) {
        return
            deployProxy(
                defaultProxyType,
                deployer,
                label,
                implementation,
                initData
            );
    }

    function deployProxy(
        ProxyType _proxyType,
        Senders.Sender storage deployer,
        string memory label,
        address implementation,
        bytes memory initData
    ) internal returns (address proxy) {
        if (_proxyType == ProxyType.CELO) {
            proxy = deployCeloProxy(deployer, label, implementation, initData);
        } else if (_proxyType == ProxyType.OZTUP) {
            proxy = deployOztupProxy(deployer, label, implementation, initData);
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
    }

    function deployCeloProxy(
        Senders.Sender storage deployer,
        string memory label,
        address implementation,
        bytes memory initData
    ) internal returns (address proxy) {
        proxy = deployer.create3(CELO_ARTIFACT).setLabel(label).deploy(
            abi.encode(deployer.account)
        );
        ILegacyProxy iProxy = ILegacyProxy(deployer.harness(proxy));
        if (initData.length > 0) {
            iProxy._setAndInitializeImplementation(implementation, initData);
        } else {
            iProxy._setImplementation(implementation);
        }
    }

    function deployOztupProxy(
        Senders.Sender storage deployer,
        string memory label,
        address implementation,
        bytes memory initData
    ) internal returns (address proxy) {
        address proxyAdmin = lookup("ProxyAdmin");
        require(proxyAdmin != address(0), "ProxyAdmin not deployed");
        proxy = deployer.create3(OZTUP_ARTIFACT).setLabel(label).deploy(
            abi.encode(implementation, proxyAdmin, initData)
        );
    }
}
