// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ProxyViewHelper} from "./ProxyViewHelper.sol";

enum ProxyType {
    CELO, // Celo Legacy Proxy
    OZTUP // Open Zeppeling TransparentUpgradeableProxy
}

string constant CELO_LOOKUP_PREFIX = "Proxy:";
string constant OZTUP_LOOKUP_PREFIX = "TransparentUpgradeableProxy:";
string constant CELO_ARTIFACT = "src/Proxy.sol:Proxy";
string constant OZTUP_ARTIFACT = "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";

interface ILegacyProxy {
    function _setImplementation(address implementation) external;

    function _setAndInitializeImplementation(
        address implementation,
        bytes calldata init
    ) external;

    function _transferOwnership(address newOwner) external;
}

contract ProxyHelper is TrebScript, ProxyViewHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using Strings for address;

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
            defaultProxyType = ProxyType.OZTUP;
        }
    }

    function lookupProxy(
        string memory contractName
    ) internal view returns (address proxy) {
        address celo = lookup(
            string.concat(CELO_LOOKUP_PREFIX, contractName)
        );
        address oztup = lookup(
            string.concat(OZTUP_LOOKUP_PREFIX, contractName)
        );
        require(
            celo == address(0) || oztup == address(0),
            string.concat(
                contractName,
                " found as both Celo and OZTUP proxy, be explicit"
            )
        );
        proxy = celo != address(0) ? celo : oztup;
    }

    function lookupProxy(
        string memory contractName,
        string memory namespace
    ) internal view returns (address proxy) {
        proxy = lookupProxy(contractName, defaultProxyType, namespace);
    }

    function lookupProxy(
        string memory contractName,
        ProxyType _proxyType,
        string memory namespace
    ) internal view returns (address proxy) {
        string memory identifier;
        if (_proxyType == ProxyType.CELO) {
            identifier = string.concat(CELO_LOOKUP_PREFIX, contractName);
        } else if (_proxyType == ProxyType.OZTUP) {
            identifier = string.concat(OZTUP_LOOKUP_PREFIX, contractName);
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
        proxy = lookup(identifier, namespace);
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
        string memory contractName,
        string memory namespace
    ) internal view returns (address proxy) {
        proxy = lookupProxyOrFail(contractName, defaultProxyType, namespace);
    }

    function lookupProxyOrFail(
        string memory contractName
    ) internal view returns (address proxy) {
        proxy = lookupProxy(contractName);
        require(
            proxy != address(0),
            string.concat(contractName, " proxy not deployed")
        );
    }

    function lookupProxyOrFail(
        string memory contractName,
        ProxyType _proxyType,
        string memory namespace
    ) internal view returns (address proxy) {
        string memory identifier;
        if (_proxyType == ProxyType.CELO) {
            identifier = string.concat(CELO_LOOKUP_PREFIX, contractName);
        } else if (_proxyType == ProxyType.OZTUP) {
            identifier = string.concat(OZTUP_LOOKUP_PREFIX, contractName);
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
        proxy = lookupOrFail(identifier, namespace);
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

    function lookupOrFail(
        string memory identifier,
        string memory namespace
    ) internal view returns (address addy) {
        addy = lookup(identifier, namespace);
        require(addy != address(0), string.concat(identifier, " not deployed"));
    }

    function lookupWithCodeOrFail(
        string memory identifier
    ) internal view returns (address impl) {
        impl = lookupOrFail(identifier);
        require(
            impl.code.length > 0,
            string.concat(identifier, " has no code")
        );
    }

    function lookupProxyWithCodeOrFail(
        string memory identifier
    ) internal view returns (address proxy) {
        proxy = lookupProxyOrFail(identifier);
        require(
            proxy.code.length > 0,
            string.concat(identifier, " has no code")
        );
    }

    function predictProxy(
        Senders.Sender storage deployer,
        string memory label
    ) internal returns (address proxy) {
        return predictProxy(defaultProxyType, deployer, label);
    }

    function predictProxy(
        ProxyType _proxyType,
        Senders.Sender storage deployer,
        string memory label
    ) internal returns (address proxy) {
        if (_proxyType == ProxyType.CELO) {
            proxy = deployer.create3(CELO_ARTIFACT).setLabel(label).predict();
        } else if (_proxyType == ProxyType.OZTUP) {
            proxy = deployer.create3(OZTUP_ARTIFACT).setLabel(label).predict();
        } else {
            revert UnsupportedProxyType(_proxyType);
        }
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
        proxy = deployer.create3(OZTUP_ARTIFACT).setLabel(label).deploy(
            abi.encode(implementation, deployer.account, initData)
        );
    }

    function getOZTUPProxyImplementation(
        address proxy
    ) internal view returns (address implementation) {
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxy, implSlot))));
    }

    function verifyProxyAdmin(
        string memory identifier,
        address proxy
    ) internal view {
        address proxyAdmin = lookup("ProxyAdmin");
        address currentProxyAdmin = getProxyAdmin(proxy);
        require(
            currentProxyAdmin == proxyAdmin,
            string.concat(
                identifier,
                " proxy admin mismatch\n",
                currentProxyAdmin.toHexString(),
                " != ",
                proxyAdmin.toHexString()
            )
        );
    }

    function verifyProxyImpl(
        string memory identifier,
        address proxy,
        address expectedImpl
    ) internal view {
        address actualImpl = getProxyImplementation(proxy);
        require(
            actualImpl == expectedImpl,
            string.concat(identifier, " proxy implementation mismatch")
        );
    }
}
