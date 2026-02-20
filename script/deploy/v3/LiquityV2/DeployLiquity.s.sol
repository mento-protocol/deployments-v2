// solhint-disable max-line-length, function-max-lines
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console2 as console} from "forge-std/console2.sol";

import {AddressesRegistry} from "bold/src/AddressesRegistry.sol";
import {ActivePool} from "bold/src/ActivePool.sol";
import {IBoldToken, IERC20Metadata} from "bold/src/Interfaces/IBoldToken.sol";
import {BorrowerOperations} from "bold/src/BorrowerOperations.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CollSurplusPool} from "bold/src/CollSurplusPool.sol";
import {DefaultPool} from "bold/src/DefaultPool.sol";
import {GasPool} from "bold/src/GasPool.sol";
import {HintHelpers} from "bold/src/HintHelpers.sol";
import {MultiTroveGetter} from "bold/src/MultiTroveGetter.sol";
import {SortedTroves} from "bold/src/SortedTroves.sol";
import {StabilityPool} from "bold/src/StabilityPool.sol";
import {TroveManager} from "bold/src/TroveManager.sol";
import {ICollSurplusPool} from "bold/src/Interfaces/ICollSurplusPool.sol";
import {IDefaultPool} from "bold/src/Interfaces/IDefaultPool.sol";
import {IHintHelpers} from "bold/src/Interfaces/IHintHelpers.sol";
import {IMultiTroveGetter} from "bold/src/Interfaces/IMultiTroveGetter.sol";
import {ISortedTroves} from "bold/src/Interfaces/ISortedTroves.sol";
import {IStabilityPool} from "bold/src/Interfaces/IStabilityPool.sol";
import {ITroveManager} from "bold/src/Interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "bold/src/Interfaces/IBorrowerOperations.sol";
import {IAddressesRegistry} from "bold/src/Interfaces/IAddressesRegistry.sol";
import {IActivePool} from "bold/src/Interfaces/IActivePool.sol";
import {ITroveNFT} from "bold/src/Interfaces/ITroveNFT.sol";
import {ISystemParams} from "bold/src/Interfaces/ISystemParams.sol";
import {ICollateralRegistry} from "bold/src/Interfaces/ICollateralRegistry.sol";
import {IMetadataNFT} from "bold/src/NFTMetadata/MetadataNFT.sol";

import {IStableTokenV3} from "mento-core/interfaces/IStableTokenV3.sol";
import {StableTokenV3} from "mento-core/tokens/StableTokenV3.sol";
import {
    CDPLiquidityStrategy
} from "mento-core/liquidityStrategies/CDPLiquidityStrategy.sol";

import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {TroveNFT} from "bold/src/TroveNFT.sol";
import {CollateralRegistry} from "bold/src/CollateralRegistry.sol";
import {IInterestRouter} from "bold/src/Interfaces/IInterestRouter.sol";

import {SystemParams} from "bold/src/SystemParams.sol";

import {IStableTokenV3} from "contracts/interfaces/IStableTokenV3.sol";
import {FXPriceFeed} from "bold/src/PriceFeeds/FXPriceFeed.sol";
import {
    MockInterestRouter
} from "bold/test/TestContracts/MockInterestRouter.sol";

import "bold/src/Dependencies/Constants.sol";

import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {ProxyHelper, ProxyType} from "script/helpers/ProxyHelper.sol";

import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployLiquity is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    struct LiquityContractAddresses {
        address addressesRegistry;
        address activePool;
        address borrowerOperations;
        address collSurplusPool;
        address collateralRegistry;
        address defaultPool;
        address hintHelpers;
        address sortedTroves;
        address stabilityPoolProxy;
        address systemParamsProxy;
        address troveManager;
        address troveNFT;
        address metadataNFT;
        address multiTroveGetter;
        address priceFeedProxy;
        address gasPool;
        address interestRouter;
    }

    struct LiquityContractImplementationsAddresses {
        address fxPriceFeedImplementation;
        address stabilityPoolImplementation;
        address systemParamsImplementation;
    }

    struct TroveManagerParams {
        uint256 CCR;
        uint256 MCR;
        uint256 BCR;
        uint256 SCR;
        uint256 LIQUIDATION_PENALTY_SP;
        uint256 LIQUIDATION_PENALTY_REDISTRIBUTION;
    }

    address owner;
    address watchdog;

    address oracleAdapter; // OracleAdapter Proxy needs to be deployed first
    address referenceRateFeedCDPFPMM;

    address debtToken; // Proxy of usdm token
    address collateralToken; // proxy od debtToken e.g gbpm
    address gasToken;

    address cdpLiquidityStrategy; // CDPLiquidityStrategy Proxy needs to be deployed first

    address proxyAdmin;

    LiquityContractAddresses deployedContracts;
    LiquityContractAddresses precomputedAddresses;
    LiquityContractImplementationsAddresses upgradeableContractsImplementations;
    Senders.Sender deployer;

    string constant SPECIFIC_SALT = "liquity-V2-XXXm";
    string constant SALT = "liquity-V2";

    // UpgradeableContracts:
    // - FXPriceFeed
    // - StabilityPool
    // - SystemParams

    /// @custom:senders deployer
    function run() public broadcast {
        deployer = sender("deployer");
        owner = address(123456);
        // _deployDependenciesLocalFork();

        // oracleAdapter = lookupProxyOrFail("OracleAdapter");
        // debtToken = lookupProxyOrFail("cGBP");
        // collateralToken = lookupProxyOrFail("cUSD");
        // cdpLiquidityStrategy = lookupProxyOrFail("CDPLiquidityStrategy");
        // gasToken = lookupProxyOrFail("CELO");
        // gasToken = address(4461);

        // deployAndConnectContracts();
    }

    function deployAndConnectContracts() public {
        TroveManagerParams memory troveManagerParams = TroveManagerParams({
            CCR: 150e16,
            MCR: 110e16,
            BCR: 10e16,
            SCR: 110e16,
            LIQUIDATION_PENALTY_SP: 5e16,
            LIQUIDATION_PENALTY_REDISTRIBUTION: 10e16
        });

        _deploySystemParamsDev(troveManagerParams);

        deployedContracts.addressesRegistry = deployer
            .create3("AddressesRegistry.sol:AddressesRegistry")
            .setLabel(SALT)
            .deploy(abi.encode(address(this)));

        _deployCollateralRegistry();

        deployedContracts.hintHelpers = deployer
            .create3("HintHelpers.sol:HintHelpers")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    ICollateralRegistry(deployedContracts.collateralRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.multiTroveGetter = deployer
            .create3("MultiTroveGetter.sol:MultiTroveGetter")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    ICollateralRegistry(deployedContracts.collateralRegistry)
                )
            );

        deployedContracts.interestRouter = deployer
            .create3("MockInterestRouter.sol:MockInterestRouter")
            .setLabel(SALT)
            .deploy();

        // Pre-calc addresses
        precomputedAddresses.borrowerOperations = _predict(
            "BorrowerOperations.sol:BorrowerOperations",
            deployer,
            SALT
        );
        precomputedAddresses.troveManager = _predict(
            "TroveManager.sol:TroveManager",
            deployer,
            SALT
        );
        precomputedAddresses.troveNFT = _predict(
            "TroveNFT.sol:TroveNFT",
            deployer,
            SALT
        );
        precomputedAddresses.stabilityPoolProxy = _predict(
            "StabilityPool.sol:StabilityPool",
            deployer,
            SALT
        );
        precomputedAddresses.activePool = _predict(
            "ActivePool.sol:ActivePool",
            deployer,
            SALT
        );
        precomputedAddresses.defaultPool = _predict(
            "DefaultPool.sol:DefaultPool",
            deployer,
            SALT
        );
        precomputedAddresses.gasPool = _predict(
            "GasPool.sol:GasPool",
            deployer,
            SALT
        );
        precomputedAddresses.collSurplusPool = _predict(
            "CollSurplusPool.sol:CollSurplusPool",
            deployer,
            SALT
        );
        precomputedAddresses.sortedTroves = _predict(
            "SortedTroves.sol:SortedTroves",
            deployer,
            SALT
        );

        _deployFXPriceFeed(precomputedAddresses.borrowerOperations);

        // Deploy contracts
        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry
            .AddressVars({
                borrowerOperations: IBorrowerOperations(
                    precomputedAddresses.borrowerOperations
                ),
                troveManager: ITroveManager(precomputedAddresses.troveManager),
                troveNFT: ITroveNFT(precomputedAddresses.troveNFT),
                metadataNFT: IMetadataNFT(address(0)),
                stabilityPool: IStabilityPool(
                    precomputedAddresses.stabilityPoolProxy
                ),
                priceFeed: IPriceFeed(deployedContracts.priceFeedProxy),
                activePool: IActivePool(precomputedAddresses.activePool),
                defaultPool: IDefaultPool(precomputedAddresses.defaultPool),
                gasPoolAddress: precomputedAddresses.gasPool,
                collSurplusPool: ICollSurplusPool(
                    precomputedAddresses.collSurplusPool
                ),
                sortedTroves: ISortedTroves(precomputedAddresses.sortedTroves),
                interestRouter: IInterestRouter(
                    deployedContracts.interestRouter
                ),
                hintHelpers: IHintHelpers(deployedContracts.hintHelpers),
                multiTroveGetter: IMultiTroveGetter(
                    deployedContracts.multiTroveGetter
                ),
                collateralRegistry: ICollateralRegistry(
                    deployedContracts.collateralRegistry
                ),
                boldToken: IBoldToken(debtToken),
                collToken: IERC20Metadata(collateralToken),
                gasToken: IERC20Metadata(gasToken),
                liquidityStrategy: cdpLiquidityStrategy
            });

        IAddressesRegistry(deployedContracts.addressesRegistry).setAddresses(
            addressVars
        );

        deployedContracts.borrowerOperations = deployer
            .create3("BorrowerOperations.sol:BorrowerOperations")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.troveManager = deployer
            .create3("TroveManager.sol:TroveManager")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.troveNFT = deployer
            .create3("TroveNFT.sol:TroveNFT")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry)
                )
            );

        upgradeableContractsImplementations
            .stabilityPoolImplementation = deployer
            .create3("StabilityPool.sol:StabilityPoolImplementation")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    true,
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        address _stabilityPoolProxyAddress = deployProxy(
            ProxyType.OZTUP,
            deployer,
            "StabilityPool.sol:StabilityPoolProxy",
            upgradeableContractsImplementations.stabilityPoolImplementation,
            abi.encode(IAddressesRegistry(deployedContracts.addressesRegistry))
        );

        deployedContracts.stabilityPoolProxy = _stabilityPoolProxyAddress;

        deployedContracts.activePool = deployer
            .create3("ActivePool.sol:ActivePool")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    deployedContracts.addressesRegistry,
                    ISystemParams(
                        ISystemParams(deployedContracts.systemParamsProxy)
                    )
                )
            );

        deployedContracts.defaultPool = deployer
            .create3("DefaultPool.sol:DefaultPool")
            .setLabel(SALT)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.gasPool = deployer
            .create3("GasPool.sol:GasPool")
            .setLabel(SALT)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.collSurplusPool = deployer
            .create3("CollSurplusPool.sol:CollSurplusPool")
            .setLabel(SALT)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.sortedTroves = deployer
            .create3("SortedTroves.sol:SortedTroves")
            .setLabel(SALT)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        assert(
            address(deployedContracts.borrowerOperations) ==
                precomputedAddresses.borrowerOperations
        );
        assert(
            deployedContracts.troveManager == precomputedAddresses.troveManager
        );
        assert(deployedContracts.troveNFT == precomputedAddresses.troveNFT);
        assert(
            deployedContracts.stabilityPoolProxy ==
                precomputedAddresses.stabilityPoolProxy
        );
        assert(deployedContracts.activePool == precomputedAddresses.activePool);
        assert(
            deployedContracts.defaultPool == precomputedAddresses.defaultPool
        );
        assert(deployedContracts.gasPool == precomputedAddresses.gasPool);
        assert(
            deployedContracts.collSurplusPool ==
                precomputedAddresses.collSurplusPool
        );
        assert(
            deployedContracts.sortedTroves == precomputedAddresses.sortedTroves
        );
    }

    function _deploySystemParamsDev(TroveManagerParams memory params) internal {
        // Create parameter structs based on constants
        ISystemParams.DebtParams memory debtParams = ISystemParams.DebtParams({
            minDebt: 100e18 // MIN_DEBT
        });
        ISystemParams.LiquidationParams memory liquidationParams = ISystemParams
            .LiquidationParams({
                liquidationPenaltySP: params.LIQUIDATION_PENALTY_SP,
                liquidationPenaltyRedistribution: params
                    .LIQUIDATION_PENALTY_REDISTRIBUTION
            });
        ISystemParams.GasCompParams memory gasCompParams = ISystemParams
            .GasCompParams({
                collGasCompensationDivisor: 200, // COLL_GAS_COMPENSATION_DIVISOR
                collGasCompensationCap: 2 ether, // COLL_GAS_COMPENSATION_CAP
                ethGasCompensation: 0.0375 ether // ETH_GAS_COMPENSATION
            });
        ISystemParams.CollateralParams memory collateralParams = ISystemParams
            .CollateralParams({
                ccr: params.CCR,
                scr: params.SCR,
                mcr: params.MCR,
                bcr: params.BCR
            });
        ISystemParams.InterestParams memory interestParams = ISystemParams
            .InterestParams({
                minAnnualInterestRate: DECIMAL_PRECISION / 200 // MIN_ANNUAL_INTEREST_RATE (0.5%)
            });
        ISystemParams.RedemptionParams memory redemptionParams = ISystemParams
            .RedemptionParams({
                redemptionFeeFloor: DECIMAL_PRECISION / 400, // REDEMPTION_FEE_FLOOR (0.5%)
                initialBaseRate: DECIMAL_PRECISION, // INITIAL_BASE_RATE (100%)
                redemptionMinuteDecayFactor: 998076443575628800, // REDEMPTION_MINUTE_DECAY_FACTOR
                redemptionBeta: 1 // REDEMPTION_BETA
            });
        ISystemParams.StabilityPoolParams memory poolParams = ISystemParams
            .StabilityPoolParams({
                spYieldSplit: 75 * (DECIMAL_PRECISION / 100), // SP_YIELD_SPLIT (75%)
                minBoldInSP: 1e18, // MIN_BOLD_IN_SP
                minBoldAfterRebalance: 1_000e18 // MIN_BOLD_AFTER_REBALANCE
            });
        upgradeableContractsImplementations
            .systemParamsImplementation = deployer
            .create3("SystemParams")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    true, // disableInitializers for implementation
                    debtParams,
                    liquidationParams,
                    gasCompParams,
                    collateralParams,
                    interestParams,
                    redemptionParams,
                    poolParams
                )
            );
        console.log("test");

        address _systemParamsProxyAddress = deployProxy(
            ProxyType.OZTUP,
            deployer,
            "SystemParams.sol:SystemParamsProxy",
            upgradeableContractsImplementations.systemParamsImplementation,
            ""
        );

        console.log("test2");
        deployedContracts.systemParamsProxy = _systemParamsProxyAddress;
    }

    function _deployFXPriceFeed(address borrowerOperationsAddress) internal {
        upgradeableContractsImplementations.fxPriceFeedImplementation = deployer
            .create3("FXPriceFeed.sol:FXPriceFeedImplementation")
            .setLabel(SALT)
            .deploy(abi.encode(false));

        address _fxPriceFeedProxyAddress = deployProxy(
            ProxyType.OZTUP,
            deployer,
            "FXPriceFeed.sol:FXPriceFeedProxy",
            upgradeableContractsImplementations.fxPriceFeedImplementation,
            abi.encode(
                oracleAdapter,
                referenceRateFeedCDPFPMM,
                false,
                20 minutes,
                borrowerOperationsAddress,
                watchdog,
                owner
            )
        );
        deployedContracts.priceFeedProxy = _fxPriceFeedProxyAddress;
    }

    function _deployCollateralRegistry() internal {
        address troveManagerAddress = _predict(
            "TroveManager.sol:TroveManager",
            deployer,
            SALT
        );

        precomputedAddresses.troveManager = troveManagerAddress;

        IERC20Metadata[] memory collaterals = new IERC20Metadata[](1);
        collaterals[0] = IERC20Metadata(collateralToken);

        ITroveManager[] memory troveManagers = new ITroveManager[](1);
        troveManagers[0] = ITroveManager(troveManagerAddress);

        ISystemParams systemParams = ISystemParams(
            deployedContracts.systemParamsProxy
        );

        deployedContracts.collateralRegistry = deployer
            .create3("CollateralRegistry.sol:CollateralRegistry")
            .setLabel(SALT)
            .deploy(
                abi.encode(
                    IBoldToken(address(debtToken)),
                    collaterals,
                    troveManagers,
                    systemParams,
                    cdpLiquidityStrategy
                )
            );
    }

    function _predict(
        string memory artifact,
        Senders.Sender storage _deployer,
        string memory label
    ) internal returns (address) {
        return _deployer.create3(artifact).setLabel(label).predict();
    }
}
