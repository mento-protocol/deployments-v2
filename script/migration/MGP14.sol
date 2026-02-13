// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {OZGovernor} from "lib/treb-sol/src/internal/sender/OZGovernorSender.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";
import {StableTokenV3} from "lib/mento-core/contracts/tokens/StableTokenV3.sol";
import {IBiPoolManager} from "lib/mento-core/contracts/interfaces/IBiPoolManager.sol";
import {ISortedOracles} from "lib/mento-core/contracts/interfaces/ISortedOracles.sol";
import {IBreakerBox} from "lib/mento-core/contracts/interfaces/IBreakerBox.sol";
import {IMedianDeltaBreaker} from "lib/mento-core/contracts/interfaces/IMedianDeltaBreaker.sol";
import {IValueDeltaBreaker} from "lib/mento-core/contracts/interfaces/IValueDeltaBreaker.sol";

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
    Contract[] internal proxies;
    Contract[] internal singletons;

    address internal timelockProxy;
    address internal devMultisig;

    function setupAddresses() public {
        require(isMainnet() || isSepolia(), "only mainnet or sepolia are supported");

        if (isMainnet()) {
            tokens.push(Contract(MAINNET_USDm, "USDm"));
            tokens.push(Contract(MAINNET_EURm, "EURm"));
            tokens.push(Contract(MAINNET_GBPm, "GBPm"));

            proxies.push(Contract(MAINNET_sortedOraclesProxy, "SortedOracles"));
            proxies.push(Contract(MAINNET_biPoolManagerProxy, "BiPoolManager"));

            singletons.push(Contract(MAINNET_breakerBox, "BreakerBox"));
            singletons.push(Contract(MAINNET_medianDeltaBreaker, "MedianDeltaBreaker"));
            singletons.push(Contract(MAINNET_valueDeltaBreaker, "ValueDeltaBreaker"));

            timelockProxy = MAINNET_timelockProxy;
            devMultisig = MAINNET_devMultisig;
        } else {
            tokens.push(Contract(lookupProxyOrFail("cUSD", ProxyType.CELO), "USDm"));
            tokens.push(Contract(lookupProxyOrFail("cEUR", ProxyType.CELO), "EURm"));
            tokens.push(Contract(lookupProxyOrFail("cGBP", ProxyType.CELO), "GBPm"));

            proxies.push(Contract(lookupProxyOrFail("SortedOracles", ProxyType.CELO), "SortedOracles"));
            proxies.push(Contract(lookupProxyOrFail("BiPoolManager", ProxyType.CELO), "BiPoolManager"));

            singletons.push(Contract(lookupOrFail("BreakerBox:v2.6.5"), "BreakerBox"));
            singletons.push(Contract(lookupOrFail("MedianDeltaBreaker:v2.6.5"), "MedianDeltaBreaker"));
            singletons.push(Contract(lookupOrFail("ValueDeltaBreaker:v2.6.5"), "ValueDeltaBreaker"));

            timelockProxy = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
            devMultisig = SEPOLIA_devMultisig;
        }
    }

    function transferContractOwnership(Senders.Sender storage govSender, address addr) internal {
        IOwnable(govSender.harness(addr)).transferOwnership(devMultisig);
    }

    function transferProxyAdminOwnership(Senders.Sender storage govSender, address addr) internal {
        ICeloProxy(govSender.harness(addr))._transferOwnership(devMultisig);
    }

    function transferProxies(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Transferring proxies to %s ==", devMultisig);

        for (uint256 i = 0; i < tokens.length; ++i) {
            console.log(" > %s (%s)", tokens[i].name, tokens[i].addr);
            // transfer proxy admin ownership (to be able to upgrade to stable token v3)
            transferProxyAdminOwnership(govSender, tokens[i].addr);
            // to set minter, burner, etc
            transferContractOwnership(govSender, tokens[i].addr);
        }

        for (uint256 i = 0; i < proxies.length; ++i) {
            console.log(" > %s (%s)", proxies[i].name, proxies[i].addr);
            // we don't need permissions to update the impl. on biPoolManager or sortedOracles
            // so we can just transfer the contract ownership
            transferContractOwnership(govSender, proxies[i].addr);
        }
    }

    function transferSingletons(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Transferring singletons to %s ==", devMultisig);
        for (uint256 i = 0; i < singletons.length; ++i) {
            console.log(" > %s (%s)", singletons[i].name, singletons[i].addr);
            transferContractOwnership(govSender, singletons[i].addr);
        }
    }

    /// =========== Proposal checks ===========

    function preChecks() internal view {
        console.log("== Pre-checks ==");
        console.log(unicode" > 👀 checking current ownership of %d contracts", tokens.length + proxies.length + singletons.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            require(equalStrings(IERC20Metadata(tokens[i].addr).symbol(), tokens[i].name), "unexpected token symbol");
            require(ICeloProxy(tokens[i].addr)._getOwner() == timelockProxy, "unexpected proxy owner");
        }

        for (uint256 i = 0; i < proxies.length; ++i) {
            require(ICeloProxy(proxies[i].addr)._getOwner() == timelockProxy, "unexpected proxy owner");
        }

        for (uint256 i = 0; i < singletons.length; ++i) {
            require(IOwnable(singletons[i].addr).owner() == timelockProxy, "unexpected singleton owner");
        }
    }

    function checkOwnershipTransfers() internal view {
        console.log("");
        console.log("== Post-checks ==");

        console.log(" (ownership transfers)");
        for (uint256 i = 0; i < tokens.length; ++i) {
            require(ICeloProxy(tokens[i].addr)._getOwner() == devMultisig, "unexpected token proxy admin owner");
            require(IOwnable(tokens[i].addr).owner() == devMultisig, "unexpected token contract owner");
            console.log(unicode"  > 🟢 %s proxy admin and contract ownership transferred", tokens[i].name);
        }

        for (uint256 i = 0; i < proxies.length; ++i) {
            // proxy admin ownership should remain untransferred for biPoolManager and sortedOracles
            require(ICeloProxy(proxies[i].addr)._getOwner() == timelockProxy, "unexpected proxy owner transfer");

            require(IOwnable(proxies[i].addr).owner() == devMultisig, "unexpected token contract owner");
            console.log(unicode"  > 🟢 %s contract ownership transferred", proxies[i].name);
        }

        for (uint256 i = 0; i < singletons.length; ++i) {
            require(IOwnable(singletons[i].addr).owner() == devMultisig, "unexpected singleton owner");
            console.log(unicode"  > 🟢 %s contract ownership transferred", singletons[i].name);
        }
    }

    function checkTokenContractsPermissions() internal {
        console.log("");
        // console.log("== Checking permissions on token contracts ==");
        console.log(" (permissions on token contracts)");
        StableTokenV3 stableTokenV3 = new StableTokenV3(true);

        for (uint256 i = 0; i < tokens.length; ++i) {
            // try to upgrade to stable token v3 (confirms proxy admin ownership)
            vm.prank(devMultisig);
            ICeloProxy(tokens[i].addr)._setImplementation(address(stableTokenV3));

            require(
                ICeloProxy(tokens[i].addr)._getImplementation() == address(stableTokenV3),
                "failed to upgrade token contract to stable token v3"
            );

            // try to set minter (confirms proxy ownership)
            address newMinter = address(1337);
            vm.prank(devMultisig);
            StableTokenV3(tokens[i].addr).setMinter(newMinter, true);

            require(StableTokenV3(tokens[i].addr).isMinter(newMinter), "failed to set minter role");

            console.log(
                unicode"  > 🟢 multisig can upgrade %s to stable token v3 and set minter role",
                tokens[i].name
            );
        }
    }

    function checkBiPoolManagerPermissions() internal {
        console.log("");
        console.log(" (permissions on biPoolManager)");

        // try to destroy an exchange to confirm contract ownership
        Contract memory biPoolManager = getContractByName("BiPoolManager");

        bytes32[] memory exchangeIds = IBiPoolManager(biPoolManager.addr).getExchangeIds();

        vm.prank(devMultisig);
        IBiPoolManager(biPoolManager.addr).destroyExchange(exchangeIds[0], 0);

        require(IBiPoolManager(biPoolManager.addr).getExchangeIds().length == exchangeIds.length - 1, "failed to destroy exchange");

        console.log(unicode"  > 🟢 multisig can destroy exchanges on %s", biPoolManager.name);
    }

    function checkSortedOraclesPermissions() internal {
        console.log("");
        console.log(" (permissions on sortedOracles)");

        // try to whitelist an oracle to confirm contract ownership
        Contract memory sortedOracles = getContractByName("SortedOracles");
        address sampleFeed = address(uint160(uint256(keccak256("newToken"))));
        address newOracle = address(1337);

        require(ISortedOracles(sortedOracles.addr).getOracles(sampleFeed).length == 0, "sample feed should have no oracles");

        vm.prank(devMultisig);
        ISortedOracles(sortedOracles.addr).addOracle(sampleFeed, newOracle);

        require(ISortedOracles(sortedOracles.addr).getOracles(sampleFeed).length == 1, "failed to add oracle");

        console.log(unicode"  > 🟢 multisig can whitelist oracles on %s", sortedOracles.name);
    }

    function checkBreakerBoxPermissions() internal {
        console.log("");
        console.log(" (permissions on breakerBox)");

        // try to add a breaker to confirm contract ownership
        Contract memory breakerBox = getContractByName("BreakerBox");

        address newBreaker = address(1337);
        require(!IBreakerBox(breakerBox.addr).isBreaker(newBreaker), "new breaker should not be added");

        vm.prank(devMultisig);
        IBreakerBox(breakerBox.addr).addBreaker(newBreaker, 1);

        require(IBreakerBox(breakerBox.addr).isBreaker(newBreaker), "failed to add breaker");

        console.log(unicode"  > 🟢 multisig can add breakers on %s", breakerBox.name);
    }

    function checkMedianDeltaBreakerPermissions() internal {
        console.log("");
        console.log(" (permissions on medianDeltaBreaker)");

        // try to set smoothing factor to confirm contract ownership
        Contract memory medianDeltaBreaker = getContractByName("MedianDeltaBreaker");

        uint256 defaultSmoothingFactor = IMedianDeltaBreaker(medianDeltaBreaker.addr).DEFAULT_SMOOTHING_FACTOR();
        address sampleFeed = address(uint160(uint256(keccak256("newToken"))));
        require(IMedianDeltaBreaker(medianDeltaBreaker.addr).getSmoothingFactor(sampleFeed) == defaultSmoothingFactor, "unexpected smoothing factor");

        vm.prank(devMultisig);
        IMedianDeltaBreaker(medianDeltaBreaker.addr).setSmoothingFactor(sampleFeed, 1e18);

        require(IMedianDeltaBreaker(medianDeltaBreaker.addr).getSmoothingFactor(sampleFeed) == 1e18, "failed to set smoothing factor");

        console.log(unicode"  > 🟢 multisig can set smoothing factor on %s", medianDeltaBreaker.name);
    }

    function checkValueDeltaBreakerPermissions() internal {
        console.log("");
        console.log(" (permissions on valueDeltaBreaker)");

        // try to set reference value to confirm contract ownership
        Contract memory valueDeltaBreaker = getContractByName("ValueDeltaBreaker");

        address[] memory feeds = new address[](1);
        uint256[] memory referenceValues = new uint256[](1);
        feeds[0] = address(uint160(uint256(keccak256("sampleFeed"))));
        referenceValues[0] = 1e12;

        require(IValueDeltaBreaker(valueDeltaBreaker.addr).referenceValues(feeds[0]) == 0, "unexpected reference value");

        vm.prank(devMultisig);
        IValueDeltaBreaker(valueDeltaBreaker.addr).setReferenceValues(feeds, referenceValues);

        require(IValueDeltaBreaker(valueDeltaBreaker.addr).referenceValues(feeds[0]) == referenceValues[0], "failed to set reference value");

        console.log(unicode"  > 🟢 multisig can set reference value on %s", valueDeltaBreaker.name);
    }

    /// =========== Proposal submission ===========

    function proposal() public {
        Senders.Sender storage govSender = sender("governor");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-14: Transfer USDm and EURm ownership to Dev Multisig");
        ozGovSender.setProposalDescription("./mgps/mgp14.md");

        preChecks();
        transferProxies(govSender);
        transferSingletons(govSender);

        checkOwnershipTransfers();
        checkTokenContractsPermissions();
        checkSortedOraclesPermissions();
        checkBiPoolManagerPermissions();
        checkBreakerBoxPermissions();
        checkMedianDeltaBreakerPermissions();
        checkValueDeltaBreakerPermissions();
    }

    /// @custom:senders deployer, governor
    function run() public virtual broadcast {
        setupAddresses();
        proposal();
    }

    /// =========== Helper functions ===========

    function isTokenContract(string memory name) internal pure returns (bool) {
        return equalStrings(name, "USDm") || equalStrings(name, "EURm") || equalStrings(name, "GBPm");
    }

    function isSingletonContract(string memory name) internal pure returns (bool) {
        return equalStrings(name, "BreakerBox") || equalStrings(name, "MedianDeltaBreaker")
            || equalStrings(name, "ValueDeltaBreaker");
    }

    function allContracts() internal view returns (Contract[] memory combined) {
        combined = new Contract[](tokens.length + proxies.length + singletons.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            combined[i] = tokens[i];
        }
        for (uint256 i = 0; i < proxies.length; ++i) {
            combined[i] = proxies[i];
        }
        for (uint256 i = 0; i < singletons.length; ++i) {
            combined[proxies.length + i] = singletons[i];
        }
    }

    function getContractByName(string memory name) internal view returns (Contract memory) {
        Contract[] memory contracts = allContracts();
        for (uint256 i = 0; i < contracts.length; ++i) {
            if (equalStrings(contracts[i].name, name)) {
                return contracts[i];
            }
        }
        require(false, "unknown contract name");
    }

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
