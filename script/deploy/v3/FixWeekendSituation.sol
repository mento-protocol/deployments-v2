// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TrebScript} from "lib/treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {PostChecksHelper} from "script/helpers/PostChecksHelper.sol";
import {IOracleAdapter} from "mento-core/interfaces/IOracleAdapter.sol";
import {IFPMMFactory} from "mento-core/interfaces/IFPMMFactory.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMentoConfig} from "script/config/IMentoConfig.sol";
import {Config} from "script/config/Config.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {LiquidityStrategy} from "lib/mento-core/contracts/liquidityStrategies/LiquidityStrategy.sol";
import {console} from "forge-std/console.sol";

interface IProxyAdmin {
    function upgradeAndCall(ITransparentUpgradeableProxy proxy, address implementation, bytes memory data)
        external
        payable;
}

contract FixWeekendSituation is TrebScript, ProxyHelper, PostChecksHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    address public fpmmFactory;
    address public sortedOracles;
    address public breakerBox;
    address public l2SequencerUptimeFeed;
    address public oracleAdapterImpl;
    IMentoConfig public config;

    function setUp() public {
        config = Config.get();
        fpmmFactory = lookupProxyOrFail("FPMMFactory");
        console.log("FPMMFactory", fpmmFactory);
        sortedOracles = lookupProxyOrFail("SortedOracles");
        console.log("SortedOracles", sortedOracles);
        breakerBox = lookupOrFail("BreakerBox:v2.6.5");
        console.log("BreakerBox", breakerBox);
        l2SequencerUptimeFeed = lookup("L2SequencerUptimeFeed");
        console.log("L2SequencerUptimeFeed", l2SequencerUptimeFeed);
        oracleAdapterImpl = lookup("OracleAdapter:v3.0.0");
        console.log("OracleAdapterImpl", oracleAdapterImpl);
    }

    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        Senders.Sender storage deployer = sender("deployer");
        Senders.Sender storage owner = sender("migrationOwner");

        // Deploy MarketHoursBreakerToggleable if not yet deployed
        address marketHoursBreaker =
            deployer.create3("MarketHoursBreakerToggleable").setLabel("v3.0.0").deploy(abi.encode(owner.account));
        console.log("Deployed MarketHoursBreakerToggleable", marketHoursBreaker);

        // Deploy OracleAdapterCollateral
        address oracleAdapterCollateralProxy = deployProxy(
            deployer,
            "OracleAdapterCollateral",
            oracleAdapterImpl,
            abi.encodeWithSelector(
                IOracleAdapter.initialize.selector,
                sortedOracles,
                breakerBox,
                marketHoursBreaker,
                l2SequencerUptimeFeed,
                owner.account
            )
        );
        console.log("Deployed OracleAdapterCollateral proxy", oracleAdapterCollateralProxy);

        transferProxyAdminOwnership(deployer, oracleAdapterCollateralProxy, owner.account);
        console.log("Transferred proxy admin ownership to migrationOwner", owner.account);
        verifyProxyAdminOwnership("OracleAdapterCollateral", oracleAdapterCollateralProxy, owner.account);

        IFPMMFactory fpmmFactory = IFPMMFactory(fpmmFactory);
        address[] memory fpmms = fpmmFactory.deployedFPMMAddresses();

        for (uint256 i = 0; i < fpmms.length; i++) {
            if (isCollateralFpmm(fpmms[i])) {
                console.log("Setting oracle adapter weekend for collateral fpmm", IERC20Metadata(fpmms[i]).name());
                IFPMM fpmm = IFPMM(owner.harness(fpmms[i]));

                fpmm.setOracleAdapter(oracleAdapterCollateralProxy);
            }
        }

        verifyChangesWorked();
    }

    function isCollateralFpmm(address fpmm) internal view returns (bool) {
        (address token0, address token1) = IFPMM(fpmm).tokens();
        return config.isCollateralAsset(token0) || config.isCollateralAsset(token1);
    }

    function verifyChangesWorked() internal {
        IFPMMFactory fpmmFactory = IFPMMFactory(fpmmFactory);
        address[] memory fpmms = fpmmFactory.deployedFPMMAddresses();
        vm.warp(1773486000);
        console.log("warp to weekend");
        for (uint256 i = 0; i < fpmms.length; i++) {
            IFPMM fpmm = IFPMM(fpmms[i]);
            uint256 amountIn = 100 * 10 ** IERC20Metadata(fpmm.token0()).decimals();
            console.log(
                "verify changes worked for", IERC20Metadata(fpmm.token0()).name(), IERC20Metadata(fpmm.token1()).name()
            );
            console.log("oracle adapter", address(fpmm.oracleAdapter()));
            console.log("market hours breaker", address(fpmm.oracleAdapter().marketHoursBreaker()));
            if (isCollateralFpmm(fpmms[i])) {
                console.log("is collateral fpmm");
                console.log("amount in token0", amountIn);
                uint256 amountOut = fpmm.getAmountOut(amountIn, fpmm.token0());
                console.log("amount out on Weekend", amountOut);
            } else {
                console.log("is not collateral fpmm");
                address token0 = fpmm.token0();
                vm.expectRevert(IOracleAdapter.FXMarketClosed.selector);
                fpmm.getAmountOut(amountIn, token0);
                console.log("expected revert");
            }
        }
    }
}
