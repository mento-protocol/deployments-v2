// solhint-disable max-line-length, function-max-lines
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IBoldToken, IERC20Metadata} from "bold/src/Interfaces/IBoldToken.sol";
import {StabilityPool} from "bold/src/StabilityPool.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {SystemParams} from "bold/src/SystemParams.sol";
import {FXPriceFeed} from "bold/src/PriceFeeds/FXPriceFeed.sol";
import {AddressesRegistry} from "bold/src/AddressesRegistry.sol";
import {ActivePool} from "bold/src/ActivePool.sol";
import {BorrowerOperations} from "bold/src/BorrowerOperations.sol";
import {TroveManager} from "bold/src/TroveManager.sol";
import {TroveNFT} from "bold/src/TroveNFT.sol";
import {CollSurplusPool} from "bold/src/CollSurplusPool.sol";
import {DefaultPool} from "bold/src/DefaultPool.sol";
import {GasPool} from "bold/src/GasPool.sol";
import {HintHelpers} from "bold/src/HintHelpers.sol";
import {MultiTroveGetter} from "bold/src/MultiTroveGetter.sol";
import {SortedTroves} from "bold/src/SortedTroves.sol";
import {CollateralRegistry} from "bold/src/CollateralRegistry.sol";
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
import {IMetadataNFT, MetadataNFT} from "bold/src/NFTMetadata/MetadataNFT.sol";
import {FixedAssetReader} from "bold/src/NFTMetadata/utils/FixedAssets.sol";
import {IPriceFeed} from "bold/src/Interfaces/IPriceFeed.sol";
import {IInterestRouter} from "bold/src/Interfaces/IInterestRouter.sol";

import "forge-std/console2.sol";
import {Base64} from "Solady/utils/Base64.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";
import {GnosisSafe} from "treb-sol/src/internal/sender/GnosisSafeSender.sol";
import {ProxyHelper} from "script/helpers/ProxyHelper.sol";
import {SSTORE2DataPointer} from "script/helpers/SSTORE2DataPointer.sol";
import {ILiquityConfig} from "script/config/ILiquityConfig.sol";
import {LiquityConfigLib} from "script/config/LiquityConfig.sol";
contract DeployLiquityV2 is TrebScript, ProxyHelper {
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

    address debtToken; // resolved from cfg.debtTokenLabel
    address collateralToken; // resolved from cfg.collateralTokenLabel
    address gasToken; // resolved from cfg.gasTokenLabel

    address oracleAdapter; // OracleAdapter Proxy needs to be deployed first
    address cdpLiquidityStrategy; // resolved from cfg.liquidityStrategyLabel

    ILiquityConfig.LiquityInstanceConfig cfg;

    LiquityContractAddresses deployedContracts;
    LiquityContractAddresses precomputedAddresses;
    LiquityContractImplementationsAddresses upgradeableContractsImplementations;
    Senders.Sender deployer;

    // UpgradeableContracts:
    // - FXPriceFeed
    // - StabilityPool
    // - SystemParams

    /// @custom:env {string} token
    /// @custom:senders deployer
    function run() public broadcast {
        deployer = sender("deployer");
        cfg = LiquityConfigLib.get(vm.envString("token"));

        oracleAdapter = lookupProxyOrFail(cfg.oracleAdapterLabel);
        debtToken = lookupProxyOrFail(cfg.debtTokenLabel);
        collateralToken = lookupProxyOrFail(cfg.collateralTokenLabel);
        cdpLiquidityStrategy = lookupProxyOrFail(cfg.liquidityStrategyLabel);
        gasToken = lookupProxyOrFail(cfg.gasTokenLabel);

        deployAndConnectContracts();
    }

    function deployAndConnectContracts() public {
        _deploySystemParams();

        deployedContracts.addressesRegistry = deployer
            .create3("AddressesRegistry.sol:AddressesRegistry")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(deployer.account));

        // Pre-compute all addresses before any contract that depends on them
        precomputedAddresses.troveManager = _predict(
            "TroveManager.sol:TroveManager",
            deployer,
            cfg.singletonLabel
        );

        _deployCollateralRegistry();

        deployedContracts.hintHelpers = deployer
            .create3("HintHelpers.sol:HintHelpers")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    ICollateralRegistry(deployedContracts.collateralRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.multiTroveGetter = deployer
            .create3("MultiTroveGetter.sol:MultiTroveGetter")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    ICollateralRegistry(deployedContracts.collateralRegistry)
                )
            );

        precomputedAddresses.borrowerOperations = _predict(
            "BorrowerOperations.sol:BorrowerOperations",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.troveNFT = _predict(
            "TroveNFT.sol:TroveNFT",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.stabilityPoolProxy = predictProxy(
            deployer,
            string.concat("StabilityPool:", cfg.proxyLabel)
        );
        precomputedAddresses.activePool = _predict(
            "ActivePool.sol:ActivePool",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.defaultPool = _predict(
            "DefaultPool.sol:DefaultPool",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.gasPool = _predict(
            "GasPool.sol:GasPool",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.collSurplusPool = _predict(
            "CollSurplusPool.sol:CollSurplusPool",
            deployer,
            cfg.singletonLabel
        );
        precomputedAddresses.sortedTroves = _predict(
            "SortedTroves.sol:SortedTroves",
            deployer,
            cfg.singletonLabel
        );

        _deployFXPriceFeed(precomputedAddresses.borrowerOperations);
        _deployMetadata();

        IAddressesRegistry(
            deployer.harness(deployedContracts.addressesRegistry)
        ).setAddresses(_buildAddressVars());

        deployedContracts.borrowerOperations = deployer
            .create3("BorrowerOperations.sol:BorrowerOperations")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.troveManager = deployer
            .create3("TroveManager.sol:TroveManager")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry),
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.troveNFT = deployer
            .create3("TroveNFT.sol:TroveNFT")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(deployedContracts.addressesRegistry)
                )
            );

        upgradeableContractsImplementations
            .stabilityPoolImplementation = deployer
            .create3("StabilityPool.sol:StabilityPool")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    true,
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.stabilityPoolProxy = deployOztupProxy(
            deployer,
            string.concat("StabilityPool:", cfg.proxyLabel),
            upgradeableContractsImplementations.stabilityPoolImplementation,
            abi.encodeWithSelector(
                StabilityPool.initialize.selector,
                IAddressesRegistry(deployedContracts.addressesRegistry)
            )
        );

        deployedContracts.activePool = deployer
            .create3("ActivePool.sol:ActivePool")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    deployedContracts.addressesRegistry,
                    ISystemParams(deployedContracts.systemParamsProxy)
                )
            );

        deployedContracts.defaultPool = deployer
            .create3("DefaultPool.sol:DefaultPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.gasPool = deployer
            .create3("GasPool.sol:GasPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.collSurplusPool = deployer
            .create3("CollSurplusPool.sol:CollSurplusPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        deployedContracts.sortedTroves = deployer
            .create3("SortedTroves.sol:SortedTroves")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(deployedContracts.addressesRegistry));

        assert(
            deployedContracts.borrowerOperations ==
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

        _transferProxyAdminOwnerships();
        _verify();
        _previewNFT();
    }

    function _buildAddressVars()
        internal
        view
        returns (IAddressesRegistry.AddressVars memory)
    {
        return
            IAddressesRegistry.AddressVars({
                borrowerOperations: IBorrowerOperations(
                    precomputedAddresses.borrowerOperations
                ),
                troveManager: ITroveManager(precomputedAddresses.troveManager),
                troveNFT: ITroveNFT(precomputedAddresses.troveNFT),
                metadataNFT: IMetadataNFT(deployedContracts.metadataNFT),
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
                interestRouter: IInterestRouter(cfg.yieldSplitAddress),
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
    }

    function _transferProxyAdminOwnerships() internal {
        Ownable(
            deployer.harness(getProxyAdmin(deployedContracts.priceFeedProxy))
        ).transferOwnership(cfg.owner);
        Ownable(
            deployer.harness(
                getProxyAdmin(deployedContracts.stabilityPoolProxy)
            )
        ).transferOwnership(cfg.owner);
        Ownable(
            deployer.harness(getProxyAdmin(deployedContracts.systemParamsProxy))
        ).transferOwnership(cfg.owner);
    }

    function _deploySystemParams() internal {
        ISystemParams.DebtParams memory debtParams = ISystemParams.DebtParams({
            minDebt: cfg.minDebt
        });
        ISystemParams.LiquidationParams memory liquidationParams = ISystemParams
            .LiquidationParams({
                liquidationPenaltySP: cfg.liquidationPenaltySP,
                liquidationPenaltyRedistribution: cfg
                    .liquidationPenaltyRedistribution
            });
        ISystemParams.GasCompParams memory gasCompParams = ISystemParams
            .GasCompParams({
                collGasCompensationDivisor: cfg.collGasCompensationDivisor,
                collGasCompensationCap: cfg.collGasCompensationCap,
                ethGasCompensation: cfg.ethGasCompensation
            });
        ISystemParams.CollateralParams memory collateralParams = ISystemParams
            .CollateralParams({
                ccr: cfg.CCR,
                scr: cfg.SCR,
                mcr: cfg.MCR,
                bcr: cfg.BCR
            });
        ISystemParams.InterestParams memory interestParams = ISystemParams
            .InterestParams({minAnnualInterestRate: cfg.minAnnualInterestRate});
        ISystemParams.RedemptionParams memory redemptionParams = ISystemParams
            .RedemptionParams({
                redemptionFeeFloor: cfg.redemptionFeeFloor,
                initialBaseRate: cfg.initialBaseRate,
                redemptionMinuteDecayFactor: cfg.redemptionMinuteDecayFactor,
                redemptionBeta: cfg.redemptionBeta
            });
        ISystemParams.StabilityPoolParams memory poolParams = ISystemParams
            .StabilityPoolParams({
                spYieldSplit: cfg.spYieldSplit,
                minBoldInSP: cfg.minBoldInSP,
                minBoldAfterRebalance: cfg.minBoldAfterRebalance
            });

        upgradeableContractsImplementations
            .systemParamsImplementation = deployer
            .create3("SystemParams.sol:SystemParams")
            .setLabel(cfg.singletonLabel)
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

        deployedContracts.systemParamsProxy = deployOztupProxy(
            deployer,
            string.concat("SystemParamsProxy:", cfg.proxyLabel),
            upgradeableContractsImplementations.systemParamsImplementation,
            ""
        );
    }

    function _deployFXPriceFeed(address borrowerOperationsAddress) internal {
        upgradeableContractsImplementations.fxPriceFeedImplementation = deployer
            .create3("FXPriceFeed.sol:FXPriceFeed")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(true));

        deployedContracts.priceFeedProxy = deployOztupProxy(
            deployer,
            string.concat("FXPriceFeedProxy:", cfg.proxyLabel),
            upgradeableContractsImplementations.fxPriceFeedImplementation,
            abi.encodeWithSelector(
                FXPriceFeed.initialize.selector,
                oracleAdapter,
                cfg.rateFeedID,
                cfg.invertRateFeed,
                cfg.l2SequencerGracePeriod,
                borrowerOperationsAddress,
                cfg.watchdog,
                cfg.owner
            )
        );
    }

    function _deployCollateralRegistry() internal {
        IERC20Metadata[] memory collaterals = new IERC20Metadata[](1);
        collaterals[0] = IERC20Metadata(collateralToken);

        ITroveManager[] memory troveManagers = new ITroveManager[](1);
        troveManagers[0] = ITroveManager(precomputedAddresses.troveManager);

        deployedContracts.collateralRegistry = deployer
            .create3("CollateralRegistry.sol:CollateralRegistry")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IBoldToken(address(debtToken)),
                    collaterals,
                    troveManagers,
                    ISystemParams(deployedContracts.systemParamsProxy),
                    cdpLiquidityStrategy
                )
            );
    }

    // ── Verification ────────────────────────────────────────────────────────

    function _verify() internal view {
        IAddressesRegistry ar = IAddressesRegistry(
            deployedContracts.addressesRegistry
        );
        ICollateralRegistry cr = ICollateralRegistry(
            deployedContracts.collateralRegistry
        );
        ISystemParams sp = ISystemParams(deployedContracts.systemParamsProxy);
        FXPriceFeed pf = FXPriceFeed(deployedContracts.priceFeedProxy);

        // ── AddressesRegistry wiring ─────────────────────────────────────
        require(
            address(ar.borrowerOperations()) ==
                deployedContracts.borrowerOperations,
            "AR: borrowerOperations"
        );
        require(
            address(ar.troveManager()) == deployedContracts.troveManager,
            "AR: troveManager"
        );
        require(
            address(ar.troveNFT()) == deployedContracts.troveNFT,
            "AR: troveNFT"
        );
        require(
            address(ar.metadataNFT()) == deployedContracts.metadataNFT,
            "AR: metadataNFT"
        );
        require(
            address(ar.stabilityPool()) == deployedContracts.stabilityPoolProxy,
            "AR: stabilityPool"
        );
        require(
            address(ar.priceFeed()) == deployedContracts.priceFeedProxy,
            "AR: priceFeed"
        );
        require(
            address(ar.activePool()) == deployedContracts.activePool,
            "AR: activePool"
        );
        require(
            address(ar.defaultPool()) == deployedContracts.defaultPool,
            "AR: defaultPool"
        );
        require(
            ar.gasPoolAddress() == deployedContracts.gasPool,
            "AR: gasPool"
        );
        require(
            address(ar.collSurplusPool()) == deployedContracts.collSurplusPool,
            "AR: collSurplusPool"
        );
        require(
            address(ar.sortedTroves()) == deployedContracts.sortedTroves,
            "AR: sortedTroves"
        );
        require(
            address(ar.interestRouter()) == cfg.yieldSplitAddress,
            "AR: interestRouter"
        );
        require(
            address(ar.hintHelpers()) == deployedContracts.hintHelpers,
            "AR: hintHelpers"
        );
        require(
            address(ar.multiTroveGetter()) ==
                deployedContracts.multiTroveGetter,
            "AR: multiTroveGetter"
        );
        require(
            address(ar.collateralRegistry()) ==
                deployedContracts.collateralRegistry,
            "AR: collateralRegistry"
        );
        require(address(ar.boldToken()) == debtToken, "AR: boldToken");
        require(address(ar.collToken()) == collateralToken, "AR: collToken");
        require(address(ar.gasToken()) == gasToken, "AR: gasToken");
        require(
            ar.liquidityStrategy() == cdpLiquidityStrategy,
            "AR: liquidityStrategy"
        );

        // ── CollateralRegistry wiring ────────────────────────────────────
        require(cr.totalCollaterals() == 1, "CR: totalCollaterals");
        require(
            address(cr.getToken(0)) == collateralToken,
            "CR: collateral[0]"
        );
        require(
            address(cr.getTroveManager(0)) == deployedContracts.troveManager,
            "CR: troveManager[0]"
        );
        require(address(cr.boldToken()) == debtToken, "CR: boldToken");
        require(
            cr.liquidityStrategy() == cdpLiquidityStrategy,
            "CR: liquidityStrategy"
        );

        // ── MetadataNFT wiring ──────────────────────────────────────────
        MetadataNFT nft = MetadataNFT(deployedContracts.metadataNFT);
        FixedAssetReader assetReader = nft.assetReader();
        require(address(assetReader) != address(0), "NFT: assetReader not set");
        require(
            assetReader.pointer() != address(0),
            "NFT: SSTORE2 pointer not set"
        );
        require(
            bytes(assetReader.readAsset(bytes4(keccak256("BOLD")))).length > 0,
            "NFT: debt token logo asset empty"
        );
        require(
            bytes(
                assetReader.readAsset(
                    bytes4(keccak256(bytes(cfg.collateralTokenSymbol)))
                )
            ).length > 0,
            "NFT: collateral logo asset empty"
        );
        require(
            bytes(assetReader.readAsset(bytes4(keccak256("geist")))).length > 0,
            "NFT: font asset empty"
        );

        // ── FXPriceFeed proxy parameters ─────────────────────────────────
        require(
            address(pf.oracleAdapter()) == oracleAdapter,
            "PF: oracleAdapter"
        );
        require(pf.rateFeedID() == cfg.rateFeedID, "PF: rateFeedID");
        require(
            pf.invertRateFeed() == cfg.invertRateFeed,
            "PF: invertRateFeed"
        );
        require(
            pf.l2SequencerGracePeriod() == cfg.l2SequencerGracePeriod,
            "PF: l2SequencerGracePeriod"
        );
        require(pf.watchdogAddress() == cfg.watchdog, "PF: watchdog");
        require(
            address(pf.borrowerOperations()) ==
                deployedContracts.borrowerOperations,
            "PF: borrowerOperations"
        );
        require(
            Ownable(deployedContracts.priceFeedProxy).owner() == cfg.owner,
            "PF: owner"
        );

        // ── SystemParams proxy parameters ────────────────────────────────
        require(sp.CCR() == cfg.CCR, "SP: CCR");
        require(sp.MCR() == cfg.MCR, "SP: MCR");
        require(sp.BCR() == cfg.BCR, "SP: BCR");
        require(sp.SCR() == cfg.SCR, "SP: SCR");
        require(
            sp.LIQUIDATION_PENALTY_SP() == cfg.liquidationPenaltySP,
            "SP: liquidationPenaltySP"
        );
        require(
            sp.LIQUIDATION_PENALTY_REDISTRIBUTION() ==
                cfg.liquidationPenaltyRedistribution,
            "SP: liquidationPenaltyRedistribution"
        );
        require(sp.MIN_DEBT() == cfg.minDebt, "SP: minDebt");
        require(
            sp.COLL_GAS_COMPENSATION_DIVISOR() ==
                cfg.collGasCompensationDivisor,
            "SP: collGasCompensationDivisor"
        );
        require(
            sp.COLL_GAS_COMPENSATION_CAP() == cfg.collGasCompensationCap,
            "SP: collGasCompensationCap"
        );
        require(
            sp.ETH_GAS_COMPENSATION() == cfg.ethGasCompensation,
            "SP: ethGasCompensation"
        );
        require(
            sp.MIN_ANNUAL_INTEREST_RATE() == cfg.minAnnualInterestRate,
            "SP: minAnnualInterestRate"
        );
        require(
            sp.REDEMPTION_FEE_FLOOR() == cfg.redemptionFeeFloor,
            "SP: redemptionFeeFloor"
        );
        require(
            sp.INITIAL_BASE_RATE() == cfg.initialBaseRate,
            "SP: initialBaseRate"
        );
        require(
            sp.REDEMPTION_MINUTE_DECAY_FACTOR() ==
                cfg.redemptionMinuteDecayFactor,
            "SP: redemptionMinuteDecayFactor"
        );
        require(
            sp.REDEMPTION_BETA() == cfg.redemptionBeta,
            "SP: redemptionBeta"
        );
        require(sp.SP_YIELD_SPLIT() == cfg.spYieldSplit, "SP: spYieldSplit");
        require(sp.MIN_BOLD_IN_SP() == cfg.minBoldInSP, "SP: minBoldInSP");
        require(
            sp.MIN_BOLD_AFTER_REBALANCE() == cfg.minBoldAfterRebalance,
            "SP: minBoldAfterRebalance"
        );

        // ── Proxy upgradeability: ProxyAdmin owner == cfg.owner ─────────
        require(
            Ownable(getProxyAdmin(deployedContracts.priceFeedProxy)).owner() ==
                cfg.owner,
            "ProxyAdmin: priceFeed"
        );
        require(
            Ownable(getProxyAdmin(deployedContracts.stabilityPoolProxy))
                .owner() == cfg.owner,
            "ProxyAdmin: stabilityPool"
        );
        require(
            Ownable(getProxyAdmin(deployedContracts.systemParamsProxy))
                .owner() == cfg.owner,
            "ProxyAdmin: systemParams"
        );
    }

    function _base64encode(string memory filePath) internal returns (bytes memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string.concat("base64 ", filePath, " | tr -d '\\n'");
        return vm.ffi(cmd);
    }

    function _deployMetadata() internal {
        string memory basePath = string.concat(
            vm.projectRoot(),
            "/",
            cfg.metadataAssetsBasePath
        );

        // Load asset files (base64-encode SVGs at deploy time)
        bytes memory debtTokenLogo = _base64encode(
            string.concat(basePath, cfg.debtTokenLogoFile)
        );
        bytes memory collateralLogo = _base64encode(
            string.concat(basePath, cfg.collateralTokenLogoFile)
        );
        bytes memory font = bytes(
            vm.readFile(string.concat(basePath, cfg.fontFile))
        );

        // Calculate byte offsets
        uint128 debtLogoEnd = uint128(debtTokenLogo.length);
        uint128 collLogoEnd = debtLogoEnd + uint128(collateralLogo.length);
        uint128 fontEnd = collLogoEnd + uint128(font.length);

        // Concatenate all data
        bytes memory allData = bytes.concat(
            debtTokenLogo,
            collateralLogo,
            font
        );

        // Deploy SSTORE2DataPointer which calls SSTORE2.write in its constructor
        address dataPointerContract = deployer
            .create3("SSTORE2DataPointer.sol:SSTORE2DataPointer")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(allData));
        address pointer = SSTORE2DataPointer(dataPointerContract).pointer();

        // Deploy FixedAssetReader via create3
        bytes4[] memory sigs = new bytes4[](3);
        sigs[0] = bytes4(keccak256("BOLD"));
        sigs[1] = bytes4(keccak256(bytes(cfg.collateralTokenSymbol)));
        sigs[2] = bytes4(keccak256("geist"));

        FixedAssetReader.Asset[]
            memory metadataAssets = new FixedAssetReader.Asset[](3);
        metadataAssets[0] = FixedAssetReader.Asset(0, debtLogoEnd);
        metadataAssets[1] = FixedAssetReader.Asset(debtLogoEnd, collLogoEnd);
        metadataAssets[2] = FixedAssetReader.Asset(collLogoEnd, fontEnd);

        address fixedAssetReader = deployer
            .create3("FixedAssets.sol:FixedAssetReader")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(pointer, sigs, metadataAssets));

        // Deploy MetadataNFT via create3
        deployedContracts.metadataNFT = deployer
            .create3("MetadataNFT.sol:MetadataNFT")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(FixedAssetReader(fixedAssetReader)));
    }

    function _predict(
        string memory artifact,
        Senders.Sender storage _deployer,
        string memory label
    ) internal returns (address) {
        return _deployer.create3(artifact).setLabel(label).predict();
    }

    function _previewNFT() internal {
        IMetadataNFT.TroveData memory troveData;
        troveData._tokenId = 1;
        troveData._owner = address(0xBEEF);
        troveData._collToken = collateralToken;
        troveData._boldToken = debtToken;
        troveData._collAmount = 10e18;
        troveData._debtAmount = 5000e18;
        troveData._interestRate = 5e16; // 5%
        troveData._status = ITroveManager.Status.active;

        string memory dataURI = MetadataNFT(deployedContracts.metadataNFT).uri(
            troveData
        );

        // Strip "data:application/json;base64," prefix (29 chars) and decode
        bytes memory jsonBytes = Base64.decode(_substring(dataURI, 29));
        string memory json = string(jsonBytes);

        // Extract SVG image from metadata and write to out/
        string memory imageDataURI = abi.decode(vm.parseJson(json, ".image"), (string));
        // Strip "data:image/svg+xml;base64," prefix (26 chars) and decode
        bytes memory svgBytes = Base64.decode(_substring(imageDataURI, 26));

        string memory svgPath = string.concat("out/nft-preview-", cfg.proxyLabel, ".svg");
        vm.writeFile(svgPath, string(svgBytes));
        console2.log("=== NFT preview SVG written to: %s ===", svgPath);
    }

    function _substring(
        string memory str,
        uint256 startIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length - startIndex);
        for (uint256 i = startIndex; i < strBytes.length; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
}
