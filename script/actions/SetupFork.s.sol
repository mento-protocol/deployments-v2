// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {IOwnable} from "mento-core/interfaces/IOwnable.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {SenderTypes} from "lib/treb-sol/src/internal/types.sol";
import {TrebForkScript} from "lib/treb-sol/src/TrebForkScript.sol";
import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";

import {MockCELO} from "../helpers/MockCELO.sol";
import {ProxyHelper, ProxyType} from "../helpers/ProxyHelper.sol";
import {OracleHelper} from "../helpers/OracleHelper.sol";
import {Config, IMentoConfig} from "../config/Config.sol";

address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;

interface ISafeOwnerMgr {
    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);

    function isOwner(address owner) external view returns (bool);

    function addOwnerWithThreshold(address owner, uint256 threshold) external;

    function removeOwner(address prevOwner, address owner, uint256 threshold) external;

    function changeThreshold(uint256 threshold) external;
}

interface IMintable {
    function mint(address to, uint256 value) external;

    function getRoleMembers(string calldata role) external view returns (address[] memory);
}

interface IMockERC20 is IERC20 {
    function mint(address to, uint256 value) external;

    function burn(address from, uint256 value) external;
}

contract SetupFork is TrebForkScript, ProxyHelper {
    using Senders for Senders.Sender;

    uint256 private constant CELO_MAINNET_CHAIN_ID = 42220;
    uint256 private constant CELO_SEPOLIA_CHAIN_ID = 11142220;
    uint256 private constant MONAD_MAINNET_CHAIN_ID = 143;
    uint256 private constant MONAD_TESTNET_CHAIN_ID = 10143;

    uint256 private constant CELO_MAINNET_STABLE_AMOUNT = 10;
    uint256 internal constant MINT_AMOUNT = 10_000_000 ether;

    address private constant SENTINEL_OWNERS = address(0x1);
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private constant USDm = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address private constant EURm = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
    address private constant GBPm = 0xCCF663b1fF11028f0b19058d0f7B674004a40746;
    address private constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
    address private constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
    address private constant axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

    error ForkModeRequired();
    error UnsupportedForkChain(uint256 chainId);

    /// @custom:senders deployer, migrationOwner, signer
    function run() public broadcast {
        if (!isForkMode) revert ForkModeRequired();

        if (block.chainid == CELO_MAINNET_CHAIN_ID) {
            setupChain_celo();
            return;
        }
        if (block.chainid == CELO_SEPOLIA_CHAIN_ID) {
            setupChain_celoSepolia();
            return;
        }
        if (block.chainid == MONAD_MAINNET_CHAIN_ID) {
            setupChain_monad();
            return;
        }
        if (block.chainid == MONAD_TESTNET_CHAIN_ID) {
            setupChain_monadTestnet();
            return;
        }

        revert UnsupportedForkChain(block.chainid);
    }

    function setupChain_celo() internal {
        Senders.Sender storage signerSender = sender("signer");
        Senders.Sender storage deployerSender = sender("deployer");
        Senders.Sender storage migrationOwnerSender = sender("migrationOwner");

        _ensureSafeIs1of1(deployerSender, signerSender.account, "deployer");
        _ensureSafeIs1of1(migrationOwnerSender, signerSender.account, "migrationOwner");

        _etchCeloMock();
        _dealMock(CELO, signerSender.account, MINT_AMOUNT);
        _dealMock(CELO, deployerSender.account, MINT_AMOUNT);
        _dealMock(CELO, migrationOwnerSender.account, MINT_AMOUNT);

        console.log("CELO (MockERC20) etched at:", CELO);
        console.log("  signer balance:", MockCELO(CELO).balanceOf(signerSender.account));
        console.log("  deployer balance:", MockCELO(CELO).balanceOf(deployerSender.account));
        console.log("  migrationOwner balance:", MockCELO(CELO).balanceOf(migrationOwnerSender.account));

        address migrationOwner = migrationOwnerSender.account;
        dealFork(USDm, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e18);
        dealFork(EURm, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e18);
        dealFork(GBPm, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e18);
        dealFork(USDC, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e6);
        _dealOwnable(USDT, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e6);
        dealFork(axlUSDC, migrationOwner, CELO_MAINNET_STABLE_AMOUNT * 1e6);

        console.log("ERC20 balances set for migrationOwner:", migrationOwner);
        console.log("  USDm:", IERC20(USDm).balanceOf(migrationOwner));
        console.log("  EURm:", IERC20(EURm).balanceOf(migrationOwner));
        console.log("  GBPm:", IERC20(GBPm).balanceOf(migrationOwner));
        console.log("  USDC:", IERC20(USDC).balanceOf(migrationOwner));
        console.log("  USDT:", IERC20(USDT).balanceOf(migrationOwner));
        console.log("  axlUSDC:", IERC20(axlUSDC).balanceOf(migrationOwner));

        IMentoConfig config = Config.get();
        address sortedOracles = lookupProxyOrFail("SortedOracles");
        OracleHelper.refreshOracleRatesIfFork(sortedOracles, config);
        console.log("Oracle rates refreshed on simulation fork and Anvil node");
    }

    function setupChain_celoSepolia() internal {
        Senders.Sender storage deployerSender = sender("deployer");
        Senders.Sender storage migrationOwnerSender = sender("migrationOwner");

        _etchCeloMock();
        _dealMock(CELO, deployerSender.account, MINT_AMOUNT);
        _dealMock(CELO, migrationOwnerSender.account, MINT_AMOUNT);

        console.log("CELO (MockERC20) etched at:", CELO);
        console.log("  deployer balance:", MockCELO(CELO).balanceOf(deployerSender.account));
        console.log("  migrationOwner balance:", MockCELO(CELO).balanceOf(migrationOwnerSender.account));
    }

    function setupChain_monad() internal {
        Senders.Sender storage signerSender = sender("signer");
        Senders.Sender storage deployerSender = sender("deployer");
        Senders.Sender storage migrationOwnerSender = sender("migrationOwner");

        _ensureSafeIs1of1(deployerSender, signerSender.account, "deployer");
        _ensureSafeIs1of1(migrationOwnerSender, signerSender.account, "migrationOwner");

        address gbpmProxy = lookupProxyOrFail("GBPm", ProxyType.OZTUP);
        address usdmProxy = lookupProxyOrFail("USDm", ProxyType.OZTUP);

        _dealAUSD(lookupOrFail("AUSD"), migrationOwnerSender.account, MINT_AMOUNT);
        _grantMinterAndMint(
            gbpmProxy,
            migrationOwnerSender,
            migrationOwnerSender.account,
            migrationOwnerSender,
            migrationOwnerSender.account,
            MINT_AMOUNT
        );
        _grantMinterAndMint(
            usdmProxy,
            migrationOwnerSender,
            migrationOwnerSender.account,
            migrationOwnerSender,
            migrationOwnerSender.account,
            MINT_AMOUNT
        );
    }

    function setupChain_monadTestnet() internal {
        Senders.Sender storage deployerSender = sender("deployer");
        Senders.Sender storage migrationOwnerSender = sender("migrationOwner");

        address gbpmProxy = lookupProxyOrFail("GBPm", ProxyType.OZTUP);
        address usdmProxy = lookupProxyOrFail("USDm", ProxyType.OZTUP);

        IMockERC20 ausd = IMockERC20(migrationOwnerSender.harness(lookupOrFail("MockERC20:AUSD")));
        ausd.mint(migrationOwnerSender.account, MINT_AMOUNT);

        _grantMinterAndMint(
            gbpmProxy,
            migrationOwnerSender,
            deployerSender.account,
            deployerSender,
            migrationOwnerSender.account,
            MINT_AMOUNT
        );
        _grantMinterAndMint(
            usdmProxy,
            migrationOwnerSender,
            deployerSender.account,
            deployerSender,
            migrationOwnerSender.account,
            MINT_AMOUNT
        );
    }

    function _ensureSafeIs1of1(Senders.Sender storage sender_, address signer, string memory label) internal {
        if (!sender_.isType(SenderTypes.GnosisSafe)) return;

        _convertCeloSafeToSingleOwner(sender_.account, signer);

        console.log(string.concat("Converted ", label, " safe to 1/1:"));
        console.log("  safe:", sender_.account);
        console.log("  threshold:", ISafeOwnerMgr(sender_.account).getThreshold());
        console.log("  signer is owner:", ISafeOwnerMgr(sender_.account).isOwner(signer));
    }

    // Celo's Safe variant does not match the storage layout assumptions in TrebForkScript,
    // so this path uses the Safe's own owner-management methods via a fork-prank sender.
    function _convertCeloSafeToSingleOwner(address safe, address newOwner) internal {
        require(newOwner != address(0) && newOwner != SENTINEL_OWNERS, "invalid owner");

        dealFork(safe, 100 ether);

        Senders.Sender storage safeSender = prankSender(safe);
        ISafeOwnerMgr safeMgr = ISafeOwnerMgr(safeSender.harness(safe));
        address[] memory currentOwners = ISafeOwnerMgr(safe).getOwners();
        bool alreadyOwner = ISafeOwnerMgr(safe).isOwner(newOwner);

        if (!alreadyOwner) {
            safeMgr.addOwnerWithThreshold(newOwner, 1);
        } else {
            safeMgr.changeThreshold(1);
        }

        for (uint256 i = 0; i < currentOwners.length; i++) {
            if (currentOwners[i] == newOwner) continue;
            address prevOwner = _findPrevOwner(safe, currentOwners[i]);
            safeMgr.removeOwner(prevOwner, currentOwners[i], 1);
        }
    }

    function _findPrevOwner(address safe, address owner) internal view returns (address) {
        address[] memory owners = ISafeOwnerMgr(safe).getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                return i == 0 ? SENTINEL_OWNERS : owners[i - 1];
            }
        }
        revert("owner not found in safe");
    }

    function _dealAUSD(address ausd, address to, uint256 amount) internal {
        bytes32 baseSlot = 0x455730fed596673e69db1907be2e521374ba893f1a04cc5f5dd931616cd6b700;
        bytes32 accountSlot = keccak256(abi.encode(to, baseSlot));
        // Preserve the isFrozen flag (lowest byte), write balance into upper 248 bits.
        bytes32 current = vm.load(ausd, accountSlot);
        bytes32 newVal = bytes32((amount << 8) | (uint256(current) & 0xff));
        vm.store(ausd, accountSlot, newVal);
    }

    function _grantMinterAndMint(
        address tokenProxy,
        Senders.Sender storage ownerSender,
        address minterAccount,
        Senders.Sender storage minterSender,
        address recipient,
        uint256 amount
    ) internal {
        IStableTokenV3 ownerView = IStableTokenV3(ownerSender.harness(tokenProxy));
        ownerView.setMinter(minterAccount, true);

        IStableTokenV3 minterView = IStableTokenV3(minterSender.harness(tokenProxy));
        minterView.mint(recipient, amount);
    }

    function _etchCeloMock() internal {
        MockCELO mock = new MockCELO();
        etchFork(CELO, address(mock).code);
    }

    function _dealMock(address token, address to, uint256 amount) internal {
        IMockERC20(token).mint(to, amount);
    }

    function _dealOwnable(address token, address to, uint256 amount) internal {
        address owner = IOwnable(token).owner();

        vm.prank(owner);
        IMockERC20(token).mint(to, amount);
    }
}
