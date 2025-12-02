// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {IOwnable} from "lib/mento-core/contracts/interfaces/IOwnable.sol";

import {ProxyHelper, ProxyType} from "../../helpers/ProxyHelper.sol";

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

    function setAddresses() public {
        Senders.Sender storage deployer = sender("deployer");
        deployerAddress = deployer.account;

        cUSD = lookupProxyOrFail("cUSD", ProxyType.CELO);
        cEUR = lookupProxyOrFail("cEUR", ProxyType.CELO);
        cREAL = lookupProxyOrFail("cREAL", ProxyType.CELO);
        eXOF = lookupProxyOrFail("eXOF", ProxyType.CELO);
        cKES = lookupProxyOrFail("cKES", ProxyType.CELO);
        PUSO = lookupProxyOrFail("PUSO", ProxyType.CELO);
        cCOP = lookupProxyOrFail("cCOP", ProxyType.CELO);
        cGHS = lookupProxyOrFail("cGHS", ProxyType.CELO);
        cGBP = lookupProxyOrFail("cGBP", ProxyType.CELO);
        cZAR = lookupProxyOrFail("cZAR", ProxyType.CELO);
        cCAD = lookupProxyOrFail("cCAD", ProxyType.CELO);
        cAUD = lookupProxyOrFail("cAUD", ProxyType.CELO);
        cCHF = lookupProxyOrFail("cCHF", ProxyType.CELO);
        cJPY = lookupProxyOrFail("cJPY", ProxyType.CELO);
        cNGN = lookupProxyOrFail("cNGN", ProxyType.CELO);
        timelock = lookupProxyOrFail("TimelockController", ProxyType.OZTUP);
        
        stables.push(cUSD);
        stables.push(cEUR);
        stables.push(cREAL);
        stables.push(eXOF);
        stables.push(cKES);
        stables.push(PUSO);
        stables.push(cCOP);
        stables.push(cGHS);
        stables.push(cGBP);
        stables.push(cZAR);
        stables.push(cCAD);
        stables.push(cAUD);
        stables.push(cCHF);
        stables.push(cJPY);
        stables.push(cNGN);
    }

    function preChecks() internal view {
        require(timelock != address(0), "Timelock address is zero");
        require(deployerAddress != address(0), "Deployer address is zero");
        
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable token = IOwnable(tokenAddress);
            address currentOwner = token.owner();
            require(currentOwner == deployerAddress, "Expected token owner to be deployer");
        }
        console.log(unicode"✅ Pre-checks passed: All tokens owned by deployer");
    }

    function postChecks() internal view {
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable token = IOwnable(tokenAddress);
            address currentOwner = token.owner();
            require(currentOwner == timelock, "Expected token owner to be timelock");
        }
        console.log(unicode"✅ Post-checks passed: All tokens owned by timelock");
    }

    function transferAllOwnership() internal {
        Senders.Sender storage deployer = sender("deployer");
        
        for (uint256 i = 0; i < stables.length; ++i) {
            address tokenAddress = stables[i];
            IOwnable token = IOwnable(deployer.harness(tokenAddress));
            console.log(unicode"🔄 Transferring ownership of token at", tokenAddress);
            token.transferOwnership(timelock);
        }
    }

    /// @custom:senders deployer
    function run() public virtual broadcast {
        setAddresses();

        preChecks();

        transferAllOwnership();

        postChecks();
    }
}
