// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";

import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {ProxyHelper, ProxyType} from "../../helpers/ProxyHelper.sol";
import {ICeloProxy} from "lib/mento-core/contracts/interfaces/ICeloProxy.sol";

contract TransferStableTokenOwnershipToTimelock is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address internal cUSD;
    address internal cEUR;
    address internal cREAL;
    address internal eXOF;
    address internal cKES;
    address internal PUSO;
    address internal cCOP;
    address internal cGHS;
    address internal cGBP;
    address internal cZAR;
    address internal cCAD;
    address internal cAUD;
    address internal cCHF;
    address internal cJPY;
    address internal cNGN;
    address[] internal stables;
    address internal timelock;
    address internal deployerAddress;

    function setup() public {
        Senders.Sender storage deployer = sender("deployer");
        deployerAddress = deployer.account;
        console.log("Deployer address:", deployerAddress);
        timelock = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
        console.log("Timelock address:", timelock);
        console.log("\n");

        cUSD = lookupProxyOrFail("cUSD", ProxyType.CELO);
        stables.push(cUSD);

        cEUR = lookupProxyOrFail("cEUR", ProxyType.CELO);
        stables.push(cEUR);

        cREAL = lookupProxyOrFail("cREAL", ProxyType.CELO);
        stables.push(cREAL);

        eXOF = lookupProxyOrFail("eXOF", ProxyType.CELO);
        stables.push(eXOF);

        cKES = lookupProxyOrFail("cKES", ProxyType.CELO);
        stables.push(cKES);

        PUSO = lookupProxyOrFail("PUSO", ProxyType.CELO);
        stables.push(PUSO);

        cCOP = lookupProxyOrFail("cCOP", ProxyType.CELO);
        stables.push(cCOP);

        cGHS = lookupProxyOrFail("cGHS", ProxyType.CELO);
        stables.push(cGHS);

        cGBP = lookupProxyOrFail("cGBP", ProxyType.CELO);
        stables.push(cGBP);

        cZAR = lookupProxyOrFail("cZAR", ProxyType.CELO);
        stables.push(cZAR);

        cCAD = lookupProxyOrFail("cCAD", ProxyType.CELO);
        stables.push(cCAD);

        cAUD = lookupProxyOrFail("cAUD", ProxyType.CELO);
        stables.push(cAUD);

        cCHF = lookupProxyOrFail("cCHF", ProxyType.CELO);
        stables.push(cCHF);

        cJPY = lookupProxyOrFail("cJPY", ProxyType.CELO);
        stables.push(cJPY);

        cNGN = lookupProxyOrFail("cNGN", ProxyType.CELO);
        stables.push(cNGN);
    }

    function preChecks() internal view {
        require(timelock != address(0), "Timelock address is zero");
        require(deployerAddress != address(0), "Deployer address is zero");
        
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable impl = IOwnable(tokenAddress);
            ICeloProxy proxy = ICeloProxy(tokenAddress);

            require(impl.owner() == deployerAddress, "Expected token impl. owner to be deployer");
            require(proxy._getOwner() == deployerAddress, "Expected token proxy owner to be deployer");
        }
        console.log(unicode"✅ Pre-checks passed: All tokens owned by deployer");
        console.log("\n");
    }

    function postChecks() internal view {
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable impl = IOwnable(tokenAddress);
            ICeloProxy proxy = ICeloProxy(tokenAddress);

            require(impl.owner() == timelock, "Expected token impl. owner to be timelock");
            require(proxy._getOwner() == timelock, "Expected token proxy owner to be timelock");
        }
        console.log("\n");
        console.log(unicode"✅ Post-checks passed: All tokens (%d) owned by timelock", stables.length);
    }

    function transferAllOwnership() internal {
        Senders.Sender storage deployer = sender("deployer");
        
        console.log("== Transferring ownership of all (%d) tokens ==", stables.length);
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable impl = IOwnable(deployer.harness(tokenAddress));
            ICeloProxy proxy = ICeloProxy(deployer.harness(tokenAddress));

            console.log(unicode"%s (%s)", IERC20Metadata(tokenAddress).symbol(), tokenAddress);

            impl.transferOwnership(timelock);
            proxy._transferOwnership(timelock);
        }
    }

    /// @custom:senders deployer
    function run() public virtual broadcast {
        setup();

        preChecks();

        transferAllOwnership();

        postChecks();
    }
}
