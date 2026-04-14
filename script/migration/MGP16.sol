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

contract MGP16 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Senders for Senders.Sender;
    using OZGovernor for OZGovernor.Sender;

    struct Contract {
        address addr;
        string name;
    }

    Contract[] internal tokens;

    address internal timelockProxy;
    address internal migrationOwner;

    function setUp() public {
        tokens.push(Contract(lookupProxyOrFail("CHFm"), "CHFm"));
        tokens.push(Contract(lookupProxyOrFail("JPYm"), "JPYm"));

        timelockProxy = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
    }

    /// @custom:senders deployer, governor, migrationOwner
    function run() public virtual broadcast {
        Senders.Sender storage govSender = sender("governor");
        migrationOwner = sender("migrationOwner").account;
        require(migrationOwner != address(0), "migrationOwner not configured");

        OZGovernor.Sender storage ozGovSender = govSender.ozGovernor();
        ozGovSender.setTitle("MGP-16: Mento V3 Deployment Phase 2 - CHFm & JPYm Migration");
        ozGovSender.setProposalDescription("./mgps/mgp16.md");

        preChecks();

        transferTokens(govSender);

        checkOwnershipTransfers();
        checkTokenContractsPermissions();
    }

    function transferContractOwnership(Senders.Sender storage govSender, address addr) internal {
        IOwnable(govSender.harness(addr)).transferOwnership(migrationOwner);
    }

    function transferProxyAdminOwnership(Senders.Sender storage govSender, address addr) internal {
        ICeloProxy(govSender.harness(addr))._transferOwnership(migrationOwner);
    }

    function transferTokens(Senders.Sender storage govSender) internal {
        console.log("");
        console.log("== Transferring tokens to %s ==", migrationOwner);

        for (uint256 i = 0; i < tokens.length; ++i) {
            console.log(" > %s (%s)", tokens[i].name, tokens[i].addr);
            // transfer proxy admin ownership (to be able to upgrade to stable token v3)
            transferProxyAdminOwnership(govSender, tokens[i].addr);
            // to set minter, burner, etc
            transferContractOwnership(govSender, tokens[i].addr);
        }
    }

    /// =========== Proposal checks ===========

    function preChecks() internal view {
        console.log("== Pre-checks ==");
        console.log(
            unicode" > 👀 checking current ownership of %d contracts",
            tokens.length
        );

        for (uint256 i = 0; i < tokens.length; ++i) {
            require(equalStrings(IERC20Metadata(tokens[i].addr).symbol(), tokens[i].name), "unexpected token symbol");
            require(ICeloProxy(tokens[i].addr)._getOwner() == timelockProxy, "unexpected proxy owner");
        }
    }

    function checkOwnershipTransfers() internal view {
        console.log("");
        console.log("== Post-checks ==");

        console.log(" (ownership transfers)");
        for (uint256 i = 0; i < tokens.length; ++i) {
            require(ICeloProxy(tokens[i].addr)._getOwner() == migrationOwner, "unexpected token proxy admin owner");
            require(IOwnable(tokens[i].addr).owner() == migrationOwner, "unexpected token contract owner");
            console.log(unicode"  > 🟢 %s proxy admin and contract ownership transferred", tokens[i].name);
        }
    }

    function checkTokenContractsPermissions() internal {
        console.log("");
        console.log(" (permissions on token contracts)");
        StableTokenV3 stableTokenV3 = new StableTokenV3(true);

        for (uint256 i = 0; i < tokens.length; ++i) {
            // try to upgrade to stable token v3 (confirms proxy admin ownership)
            vm.prank(migrationOwner);
            ICeloProxy(tokens[i].addr)._setImplementation(address(stableTokenV3));

            require(
                ICeloProxy(tokens[i].addr)._getImplementation() == address(stableTokenV3),
                "failed to upgrade token contract to stable token v3"
            );

            // try to set minter (confirms proxy ownership)
            address newMinter = address(1337);
            vm.prank(migrationOwner);
            StableTokenV3(tokens[i].addr).setMinter(newMinter, true);

            require(StableTokenV3(tokens[i].addr).isMinter(newMinter), "failed to set minter role");

            console.log(
                unicode"  > 🟢 multisig can upgrade %s to stable token v3 and set minter role", tokens[i].name
            );
        }
    }

    /// =========== Misc Helper functions ===========

    function equalStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
