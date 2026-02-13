// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {ProxyHelper, ProxyType} from "../../helpers/ProxyHelper.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";

contract MGP14 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    uint256 constant CELO_MAINNET_CHAIN_ID = 42220;
    uint256 constant CELO_SEPOLIA_CHAIN_ID = 11142220;

    // ==== Mainnet contract addresses ====
    address constant MAINNET_USDm = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address constant MAINNET_EURm = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address constant MAINNET_GBPm = 0xCCF663b1fF11028f0b19058d0f7B674004a40746;
    address constant MAINNET_biPoolManagerProxy = 0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901;
    address constant MAINNET_sortedOraclesProxy = 0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33;
    address constant MAINNET_breakerBox = 0x303ED1df62Fa067659B586EbEe8De0EcE824Ab39;
    address constant MAINNET_medianDeltaBreaker = 0x49349F92D2B17d491e42C8fdB02D19f072F9B5D9;
    address constant MAINNET_valueDeltaBreaker = 0x4DBC33B3abA78475A5AA4BC7A5B11445d387BF68;
    address constant MAINNET_timelockProxy = 0x890DB8A597940165901372Dd7DB61C9f246e2147;
    address constant MAINNET_devMultisig = 0x58099B74F4ACd642Da77b4B7966b4138ec5Ba458;

    // ==== Sepolia contract addresses ====
    // Use the current dev wallet for now on Sepolia
    address constant SEPOLIA_devMultisig = 0x2738F38Fde510743e0c589415E0598C4ceE6eAa7;

    struct Contract {
        address addr;
        string name;
    }

    Contract[] internal tokens;
    Contract[] internal v2Contracts;
    address internal timelockProxy;
    address internal devMultisig;

    function setupAddresses() public {
        require(isMainnet() || isSepolia(), "only mainnet or sepolia are supported");

        if (isMainnet()) {
            tokens.push(Contract(MAINNET_USDm, "USDm"));
            tokens.push(Contract(MAINNET_EURm, "EURm"));
            tokens.push(Contract(MAINNET_GBPm, "GBPm"));

            v2Contracts.push(Contract(MAINNET_biPoolManagerProxy, "BiPoolManager"));
            v2Contracts.push(Contract(MAINNET_sortedOraclesProxy, "SortedOracles"));
            v2Contracts.push(Contract(MAINNET_breakerBox, "BreakerBox"));
            v2Contracts.push(Contract(MAINNET_medianDeltaBreaker, "MedianDeltaBreaker"));
            v2Contracts.push(Contract(MAINNET_valueDeltaBreaker, "ValueDeltaBreaker"));

            timelockProxy = MAINNET_timelockProxy;
            devMultisig = MAINNET_devMultisig;
        } else {
            tokens.push(Contract(lookupProxyOrFail("cUSD", ProxyType.CELO), "USDm"));
            tokens.push(Contract(lookupProxyOrFail("cEUR", ProxyType.CELO), "EURm"));
            tokens.push(Contract(lookupProxyOrFail("cGBP", ProxyType.CELO), "GBPm"));

            v2Contracts.push(Contract(lookupProxyOrFail("BiPoolManager", ProxyType.CELO), "BiPoolManager"));
            v2Contracts.push(Contract(lookupProxyOrFail("SortedOracles", ProxyType.CELO), "SortedOracles"));
            v2Contracts.push(Contract(lookupOrFail("BreakerBox:v2.6.5"), "BreakerBox"));
            v2Contracts.push(Contract(lookupOrFail("MedianDeltaBreaker:v2.6.5"), "MedianDeltaBreaker"));
            v2Contracts.push(Contract(lookupOrFail("ValueDeltaBreaker:v2.6.5"), "ValueDeltaBreaker"));

            timelockProxy = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
            devMultisig = SEPOLIA_devMultisig;
        }
    }

    function preChecks() internal view {
        console.log("== Pre-checks ==");
        console.log(unicode" > 👀 checking current ownership of %d contracts", tokens.length + v2Contracts.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            require(equalStrings(IERC20Metadata(tokens[i].addr).symbol(), tokens[i].name), "unexpected token symbol");
            require(ICeloProxy(tokens[i].addr)._getOwner() == timelockProxy, "unexpected token proxy owner");
        }

        for (uint256 i = 0; i < v2Contracts.length; ++i) {
            require(IOwnable(v2Contracts[i].addr).owner() == timelockProxy, "unexpected v2 contract owner");
        }
    }

    function transferOwnership(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Transferring ownership to %s ==", devMultisig);

        for (uint256 i = 0; i < tokens.length; ++i) {
            console.log(" > %s (%s)", tokens[i].name, tokens[i].addr);
            ICeloProxy(govSender.harness(tokens[i].addr))._transferOwnership(devMultisig);
        }

        for (uint256 i = 0; i < v2Contracts.length; ++i) {
            console.log(" > %s (%s)", v2Contracts[i].name, v2Contracts[i].addr);
            IOwnable(govSender.harness(v2Contracts[i].addr)).transferOwnership(devMultisig);
        }
    }

    function postChecks() internal view {
        console.log("");
        console.log("== Post-checks ==");
        for (uint256 i = 0; i < tokens.length; ++i) {
            require(ICeloProxy(tokens[i].addr)._getOwner() == devMultisig, "unexpected token proxy owner");
            console.log(unicode" > 🟢 %s ownership transferred", tokens[i].name);
        }

        for (uint256 i = 0; i < v2Contracts.length; ++i) {
            require(IOwnable(v2Contracts[i].addr).owner() == devMultisig, "unexpected v2 contract owner");
            console.log(unicode" > 🟢 %s ownership transferred", v2Contracts[i].name);
        }
    }

    function proposal() public {
        Senders.Sender storage govSender = sender("governor");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-14: Transfer USDm and EURm ownership to Dev Multisig");
        ozGovSender.setProposalDescription("./mgps/mgp14.md");

        preChecks();
        transferOwnership(govSender);
        postChecks();
    }

    /// @custom:senders deployer, governor
    function run() public virtual broadcast {
        setupAddresses();
        proposal();
    }

    /// ==== Helper functions ====

    function equalStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function isMainnet() internal view returns (bool) {
        return block.chainid == CELO_MAINNET_CHAIN_ID;
    }

    function isSepolia() internal view returns (bool) {
        return block.chainid == CELO_SEPOLIA_CHAIN_ID;
    }
}
