// solhint-disable max-line-length, function-max-lines
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IBoldToken, IERC20Metadata} from "bold/src/Interfaces/IBoldToken.sol";
import {StabilityPool} from "bold/src/StabilityPool.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
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
import {ILiquityConfig} from "script/config/ILiquityConfig.sol";
import {LiquityConfigLib} from "script/config/LiquityConfig.sol";

contract DeployLiquityV2_2 is TrebScript, ProxyHelper {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;
    using GnosisSafe for GnosisSafe.Sender;

    // ── External registry lookups ─────────────────────────────────────────
    address debtToken;
    address collateralToken;
    address gasToken;
    address oracleAdapter;
    address cdpLiquidityStrategy;
    address fxPriceFeedManager;
    address owner;
    address yieldSplitAddress;

    // ── Phase 1 contract addresses (predicted via create3) ────────────────
    address addressesRegistry;
    address systemParamsProxy;
    address priceFeedProxy;
    address collateralRegistry;
    address hintHelpers;
    address multiTroveGetter;
    address metadataNFT;

    // ── Phase 2 deployed addresses ────────────────────────────────────────
    address borrowerOperations;
    address troveManager;
    address troveNFT;
    address stabilityPoolImpl;
    address stabilityPoolProxy;
    address activePool;
    address defaultPool;
    address gasPool;
    address collSurplusPool;
    address sortedTroves;

    ILiquityConfig.LiquityInstanceConfig cfg;
    Senders.Sender deployer;

    /// @custom:env {string} token
    /// @custom:senders deployer, migrationOwner
    function run() public broadcast {
        deployer = sender("deployer");
        cfg = LiquityConfigLib.get(vm.envString("token"));

        // External lookups
        oracleAdapter = lookupProxyOrFail("OracleAdapter");
        debtToken = lookupProxyOrFail(cfg.debtTokenLabel);
        collateralToken = lookupProxyOrFail(cfg.collateralTokenLabel);
        cdpLiquidityStrategy = lookupProxyOrFail("CDPLiquidityStrategy");
        gasToken = lookupOrFail("CELO");
        fxPriceFeedManager = lookupOrFail("FxPriceFeedManager");
        owner = sender("migrationOwner").account;
        yieldSplitAddress = lookupOrFail("YieldSplitAddress");

        // Predict Phase 1 addresses (create3 is deterministic)
        addressesRegistry = _predict("AddressesRegistry.sol:AddressesRegistry");
        systemParamsProxy = predictProxy(
            deployer,
            string.concat("SystemParamsProxy:", cfg.proxyLabel)
        );
        priceFeedProxy = predictProxy(
            deployer,
            string.concat("FXPriceFeedProxy:", cfg.proxyLabel)
        );
        collateralRegistry = _predict(
            "CollateralRegistry.sol:CollateralRegistry"
        );
        hintHelpers = _predict("HintHelpers.sol:HintHelpers");
        multiTroveGetter = _predict("MultiTroveGetter.sol:MultiTroveGetter");
        metadataNFT = _predict("MetadataNFT.sol:MetadataNFT");

        // Precompute Phase 2 addresses (to verify Phase 1 predictions match)
        address expectedBorrowerOps = _predict(
            "BorrowerOperations.sol:BorrowerOperations"
        );
        address expectedTroveManager = _predict(
            "TroveManager.sol:TroveManager"
        );
        address expectedTroveNFT = _predict("TroveNFT.sol:TroveNFT");
        address expectedStabilityPoolProxy = predictProxy(
            deployer,
            string.concat("StabilityPool:", cfg.proxyLabel)
        );
        address expectedActivePool = _predict("ActivePool.sol:ActivePool");
        address expectedDefaultPool = _predict("DefaultPool.sol:DefaultPool");
        address expectedGasPool = _predict("GasPool.sol:GasPool");
        address expectedCollSurplusPool = _predict(
            "CollSurplusPool.sol:CollSurplusPool"
        );
        address expectedSortedTroves = _predict(
            "SortedTroves.sol:SortedTroves"
        );

        // Deploy Phase 2 contracts
        borrowerOperations = deployer
            .create3("BorrowerOperations.sol:BorrowerOperations")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(addressesRegistry),
                    ISystemParams(systemParamsProxy)
                )
            );

        troveManager = deployer
            .create3("TroveManager.sol:TroveManager")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(addressesRegistry),
                    ISystemParams(systemParamsProxy)
                )
            );

        troveNFT = deployer
            .create3("TroveNFT.sol:TroveNFT")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    IAddressesRegistry(addressesRegistry)
                )
            );

        stabilityPoolImpl = deployer
            .create3("StabilityPool.sol:StabilityPool")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    true,
                    ISystemParams(systemParamsProxy)
                )
            );

        stabilityPoolProxy = deployOztupProxy(
            deployer,
            string.concat("StabilityPool:", cfg.proxyLabel),
            stabilityPoolImpl,
            abi.encodeWithSelector(
                StabilityPool.initialize.selector,
                IAddressesRegistry(addressesRegistry)
            )
        );

        activePool = deployer
            .create3("ActivePool.sol:ActivePool")
            .setLabel(cfg.singletonLabel)
            .deploy(
                abi.encode(
                    addressesRegistry,
                    ISystemParams(systemParamsProxy)
                )
            );

        defaultPool = deployer
            .create3("DefaultPool.sol:DefaultPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(addressesRegistry));

        gasPool = deployer
            .create3("GasPool.sol:GasPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(addressesRegistry));

        collSurplusPool = deployer
            .create3("CollSurplusPool.sol:CollSurplusPool")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(addressesRegistry));

        sortedTroves = deployer
            .create3("SortedTroves.sol:SortedTroves")
            .setLabel(cfg.singletonLabel)
            .deploy(abi.encode(addressesRegistry));

        // Verify deployed addresses match Phase 1 predictions
        assert(borrowerOperations == expectedBorrowerOps);
        assert(troveManager == expectedTroveManager);
        assert(troveNFT == expectedTroveNFT);
        assert(stabilityPoolProxy == expectedStabilityPoolProxy);
        assert(activePool == expectedActivePool);
        assert(defaultPool == expectedDefaultPool);
        assert(gasPool == expectedGasPool);
        assert(collSurplusPool == expectedCollSurplusPool);
        assert(sortedTroves == expectedSortedTroves);

        _transferProxyAdminOwnerships();
        _verify();
        _previewNFT();
    }

    function _transferProxyAdminOwnerships() internal {
        Ownable(
            deployer.harness(getProxyAdmin(priceFeedProxy))
        ).transferOwnership(owner);
        Ownable(
            deployer.harness(
                getProxyAdmin(stabilityPoolProxy)
            )
        ).transferOwnership(owner);
        Ownable(
            deployer.harness(getProxyAdmin(systemParamsProxy))
        ).transferOwnership(owner);
    }

    // ── Verification ────────────────────────────────────────────────────────

    function _verify() internal view {
        IAddressesRegistry ar = IAddressesRegistry(addressesRegistry);
        ICollateralRegistry cr = ICollateralRegistry(collateralRegistry);
        ISystemParams sp = ISystemParams(systemParamsProxy);
        FXPriceFeed pf = FXPriceFeed(priceFeedProxy);

        // ── AddressesRegistry wiring ─────────────────────────────────────
        require(
            address(ar.borrowerOperations()) == borrowerOperations,
            "AR: borrowerOperations"
        );
        require(
            address(ar.troveManager()) == troveManager,
            "AR: troveManager"
        );
        require(
            address(ar.troveNFT()) == troveNFT,
            "AR: troveNFT"
        );
        require(
            address(ar.metadataNFT()) == metadataNFT,
            "AR: metadataNFT"
        );
        require(
            address(ar.stabilityPool()) == stabilityPoolProxy,
            "AR: stabilityPool"
        );
        require(
            address(ar.priceFeed()) == priceFeedProxy,
            "AR: priceFeed"
        );
        require(
            address(ar.activePool()) == activePool,
            "AR: activePool"
        );
        require(
            address(ar.defaultPool()) == defaultPool,
            "AR: defaultPool"
        );
        require(
            ar.gasPoolAddress() == gasPool,
            "AR: gasPool"
        );
        require(
            address(ar.collSurplusPool()) == collSurplusPool,
            "AR: collSurplusPool"
        );
        require(
            address(ar.sortedTroves()) == sortedTroves,
            "AR: sortedTroves"
        );
        require(
            address(ar.interestRouter()) == yieldSplitAddress,
            "AR: interestRouter"
        );
        require(
            address(ar.hintHelpers()) == hintHelpers,
            "AR: hintHelpers"
        );
        require(
            address(ar.multiTroveGetter()) == multiTroveGetter,
            "AR: multiTroveGetter"
        );
        require(
            address(ar.collateralRegistry()) == collateralRegistry,
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
            address(cr.getTroveManager(0)) == troveManager,
            "CR: troveManager[0]"
        );
        require(address(cr.boldToken()) == debtToken, "CR: boldToken");
        require(
            cr.liquidityStrategy() == cdpLiquidityStrategy,
            "CR: liquidityStrategy"
        );

        // ── MetadataNFT wiring ──────────────────────────────────────────
        MetadataNFT nft = MetadataNFT(metadataNFT);
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
        require(pf.watchdogAddress() == fxPriceFeedManager, "PF: watchdog");
        require(
            address(pf.borrowerOperations()) == borrowerOperations,
            "PF: borrowerOperations"
        );
        require(
            Ownable(priceFeedProxy).owner() == owner,
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

        // ── Proxy upgradeability: ProxyAdmin owner == owner ─────────
        require(
            Ownable(getProxyAdmin(priceFeedProxy)).owner() == owner,
            "ProxyAdmin: priceFeed"
        );
        require(
            Ownable(getProxyAdmin(stabilityPoolProxy)).owner() == owner,
            "ProxyAdmin: stabilityPool"
        );
        require(
            Ownable(getProxyAdmin(systemParamsProxy)).owner() == owner,
            "ProxyAdmin: systemParams"
        );
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

        string memory dataURI = MetadataNFT(metadataNFT).uri(troveData);

        // Strip "data:application/json;base64," prefix (29 chars) and decode
        bytes memory jsonBytes = Base64.decode(_substring(dataURI, 29));
        string memory json = string(jsonBytes);

        // Extract SVG image from metadata and write to out/
        string memory imageDataURI = abi.decode(
            vm.parseJson(json, ".image"),
            (string)
        );
        // Strip "data:image/svg+xml;base64," prefix (26 chars) and decode
        bytes memory svgBytes = Base64.decode(_substring(imageDataURI, 26));

        string memory svgPath = string.concat(
            "out/nft-preview-",
            cfg.proxyLabel,
            ".svg"
        );
        vm.writeFile(svgPath, string(svgBytes));
        console2.log("=== NFT preview SVG written to: %s ===", svgPath);
    }

    function _predict(
        string memory artifact
    ) internal returns (address) {
        return deployer.create3(artifact).setLabel(cfg.singletonLabel).predict();
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
