// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper} from "../helpers/ProxyHelper.sol";
import {IMentoConfig, BreakerType, IBiPoolManager, ITradingLimits, IPricingModule, FixidityLib} from "./IMentoConfig.sol";
import {AggregatorV3Interface} from "lib/mento-core/lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";

abstract contract MentoConfig is TrebScript, ProxyHelper, IMentoConfig {
    using Deployer for Senders.Sender;
    using Deployer for Deployer.Deployment;
    using Senders for Senders.Sender;

    // ========== Storage ==========
    TokenConfig[] internal _tokens;
    mapping(string => string) _symbolForCurrency;
    ExchangeConfig[] internal _exchanges;
    OracleConfig internal _oracleConfig;
    ReserveConfig internal _reserveConfig;
    GovernanceConfig internal _governanceConfig;
    LockingConfig internal _lockingConfig;

    address public mockAggregatorReporter;

    string[] internal _mockCollateralAssets;
    RateFeed[] internal _rateFeeds;
    address[] internal _collateralAssets;
    address[] internal _fxRateFeedIds;
    address[] internal _chainlinkRelayerRateFeedIds;
    MockAggregatorConfig[] internal _mockAggregatorConfigs;

    mapping(address rateFeedId => address[] dependencies) _rateFeedDependencies;
    mapping(address rateFeedId => bool) internal _isRateFeed;
    mapping(address rateFeedId => ChainlinkRelayerConfig)
        internal _chainlinkRelayers;
    mapping(string symbol => address) internal _collateral;
    mapping(string symbol => bool) internal _isStableToken;
    mapping(bytes32 breakerId => BreakerConfig) _breakers;
    mapping(string => address) _deployedContract;
    bytes32[] _breakerIds;

    FPMMConfig[] internal _fpmmConfigs;

    IFPMM.FPMMParams internal _defaultFPMMParams;
    /// @dev pairKey is for example "USDC/USDm" and it will be duplicated as "USDm/USDC"
    mapping(string pairKey => IFPMM.FPMMParams) internal _fpmmParams;
    uint256 internal _redemptionShortfallTolerance;

    uint256 public baseFork;
    uint256 public mockAggregatorSourceFork;

    // ========== Constructor ==========

    constructor() {
        _initialize();
        baseFork = vm.createFork(vm.envString("NETWORK"));
        vm.selectFork(baseFork);
    }

    // ========== Abstract Functions ==========

    function _initialize() internal virtual;

    // ========== View Functions ==========

    function getTokenConfigs() external view returns (TokenConfig[] memory) {
        return _tokens;
    }

    function getCollateralAssets() external view returns (address[] memory) {
        return _collateralAssets;
    }

    function getOracleConfig() external view returns (OracleConfig memory) {
        return _oracleConfig;
    }

    function getGovernanceConfig()
        external
        view
        returns (GovernanceConfig memory)
    {
        return _governanceConfig;
    }

    function getLockingConfig() external view returns (LockingConfig memory) {
        return _lockingConfig;
    }

    function getBreakerConfigs()
        external
        view
        returns (BreakerConfig[] memory configs)
    {
        configs = new BreakerConfig[](_breakerIds.length);
        for (uint i = 0; i < _breakerIds.length; i++) {
            configs[i] = abi.decode(
                abi.encode(_breakers[_breakerIds[i]]),
                (BreakerConfig)
            );
        }
    }

    function getReserveConfig() external view returns (ReserveConfig memory) {
        return _reserveConfig;
    }

    function getMockAggregatorConfigs()
        external
        returns (MockAggregatorConfig[] memory)
    {
        MockAggregatorConfig[] memory configs = new MockAggregatorConfig[](
            _mockAggregatorConfigs.length
        );

        vm.selectFork(mockAggregatorSourceFork);
        for (uint i = 0; i < _mockAggregatorConfigs.length; i++) {
            MockAggregatorConfig memory config = _mockAggregatorConfigs[i];
            AggregatorV3Interface agg = AggregatorV3Interface(config.source);

            uint8 decimals = agg.decimals();
            (, int256 initialReport, , , ) = agg.latestRoundData();

            config.initialReport = initialReport;
            config.decimals = decimals;
            configs[i] = config;
        }
        vm.selectFork(baseFork);
        return configs;
    }

    function getChainlinkRelayerConfigs()
        external
        view
        returns (ChainlinkRelayerConfig[] memory relayerConfigs)
    {
        relayerConfigs = new ChainlinkRelayerConfig[](
            _chainlinkRelayerRateFeedIds.length
        );
        for (uint i = 0; i < _chainlinkRelayerRateFeedIds.length; i++) {
            address rateFeedId = _chainlinkRelayerRateFeedIds[i];
            relayerConfigs[i] = abi.decode(
                abi.encode(_chainlinkRelayers[rateFeedId]),
                (ChainlinkRelayerConfig)
            );
        }
    }

    function getExchanges()
        external
        view
        returns (ExchangeConfig[] memory exchanges)
    {
        return _exchanges;
    }

    function getRateFeeds() external view returns (RateFeed[] memory) {
        return _rateFeeds;
    }

    function getFxRateFeedIds() external view returns (address[] memory) {
        return _fxRateFeedIds;
    }

    function getRateFeedIds()
        external
        view
        returns (address[] memory rateFeedIds)
    {
        rateFeedIds = new address[](_rateFeeds.length);
        for (uint i = 0; i < _rateFeeds.length; i++) {
            rateFeedIds[i] = _rateFeeds[i].rateFeedId;
        }
    }

    function getRateFeedDependencies(
        address rateFeed
    ) external view returns (address[] memory) {
        return _rateFeedDependencies[rateFeed];
    }

    function getMockCollaterals() external view returns (string[] memory) {
        return _mockCollateralAssets;
    }

    function getAddress(string memory token) public returns (address) {
        return _resolveExchangeAsset(token);
    }

    function getTokenForCurrency(
        string memory currency
    ) public returns (address) {
        string memory symbol = _symbolForCurrency[currency];
        require(
            bytes(symbol).length > 0,
            string.concat("Token not registered for: ", currency)
        );
        return getAddress(symbol);
    }

    function getFPMMConfigs()
        external
        view
        returns (FPMMConfig[] memory)
    {
        return _fpmmConfigs;
    }

    /// @dev Get default FPMM Params
    function getDefaultFPMMParams()
        public
        view
        returns (IFPMM.FPMMParams memory)
    {
        return _defaultFPMMParams;
    }

    /// @dev Get FPMM Params for given pair
    function getFPMMParams(
        address token0,
        address token1
    ) public view returns (IFPMM.FPMMParams memory) {
        string memory pairKey = string.concat(
            IERC20Metadata(token0).symbol(),
            "/",
            IERC20Metadata(token1).symbol()
        );
        return _fpmmParams[pairKey];
    }

    function getCDPRedemptionShortfallTolerance()
        public
        view
        returns (uint256)
    {
        return _redemptionShortfallTolerance;
    }

    // ========== Helper Functions ==========

    function emptyTradingLimits()
        internal
        pure
        returns (ITradingLimits.Config memory)
    {}

    function getRateFeedIdFromString(
        string memory feedId
    ) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(feedId)))));
    }

    function getExchangeId(
        address asset0,
        address asset1,
        address pricingModule
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    IERC20Metadata(asset0).symbol(),
                    IERC20Metadata(asset1).symbol(),
                    IPricingModule(pricingModule).name()
                )
            );
    }

    function getExchangeId(
        address asset0,
        address asset1
    ) public view returns (bytes32) {
        for (uint i = 0; i < _exchanges.length; i++) {
            ExchangeConfig storage exchange = _exchanges[i];
            if (
                (exchange.pool.asset0 == asset0 &&
                    exchange.pool.asset1 == asset1) ||
                (exchange.pool.asset1 == asset0 &&
                    exchange.pool.asset0 == asset1)
            ) {
                return
                    getExchangeId(
                        exchange.pool.asset0,
                        exchange.pool.asset1,
                        address(exchange.pool.pricingModule)
                    );
            }
        }
        revert(
            string.concat(
                "Could not find exchange for ",
                vm.toString(asset0),
                " and ",
                vm.toString(asset1)
            )
        );
    }

    function getDeployedContract(
        string memory name
    ) public view returns (address contractAddress) {
        contractAddress = _deployedContract[name];
        if (contractAddress == address(0)) {
            revert(
                string.concat("Could not find deployed contract named ", name)
            );
        }
    }

    // ========== Internal Helper Functions ==========

    function _addStableToken(
        string memory currency,
        string memory symbol,
        string memory name
    ) internal {
        _isStableToken[symbol] = true;
        _symbolForCurrency[currency] = symbol;
        _tokens.push(
            TokenConfig({symbol: symbol, name: name, currency: currency})
        );
    }

    function _addCollateral(string memory symbol, address addy) internal {
        _collateralAssets.push(addy);
        _collateral[symbol] = addy;
    }

    function _addMockCollateral(string memory symbol) internal {
        address addy;
        address lookupMock = lookup(string.concat("MockERC20:", symbol));
        if (lookupMock != address(0)) {
            addy = lookupMock;
        } else {
            addy = _predict("MockERC20", symbol);
        }
        _collateralAssets.push(addy);
        _mockCollateralAssets.push(symbol);
        _collateral[symbol] = addy;
    }

    function _addRateFeed(string memory rateFeed) internal {
        _isRateFeed[getRateFeedIdFromString(rateFeed)] = true;
        _rateFeeds.push(
            RateFeed({
                rateFeed: rateFeed,
                rateFeedId: getRateFeedIdFromString(rateFeed)
            })
        );
    }

    function _addRateFeedDependency(
        address rateFeedId,
        address dependency
    ) internal {
        _rateFeedDependencies[rateFeedId].push(dependency);
    }

    function _addRateFeedDependency(
        address rateFeedId,
        string memory dependency
    ) internal {
        address depId = getRateFeedIdFromString(dependency);
        require(
            _isRateFeed[depId],
            string.concat(dependency, " is not registered as a rate feed.")
        );

        _addRateFeedDependency(rateFeedId, depId);

        _rateFeedDependencies[rateFeedId].push(depId);
    }

    function _addRateFeedDependency(
        string memory rateFeed,
        string memory dependency
    ) internal {
        address rateFeedId = getRateFeedIdFromString(rateFeed);
        address depId = getRateFeedIdFromString(dependency);
        require(
            _isRateFeed[rateFeedId],
            string.concat(rateFeed, " is not registered as a rate feed.")
        );
        require(
            _isRateFeed[depId],
            string.concat(dependency, " is not registered as a rate feed.")
        );

        _addRateFeedDependency(rateFeedId, depId);
    }

    function _addRateFeed(
        string memory rateFeed,
        string[] memory dependencies
    ) internal {
        address rateFeedId = getRateFeedIdFromString(rateFeed);
        _isRateFeed[rateFeedId] = true;
        _rateFeeds.push(RateFeed({rateFeed: rateFeed, rateFeedId: rateFeedId}));

        for (uint i = 0; i < dependencies.length; i++) {
            _addRateFeedDependency(rateFeed, dependencies[i]);
        }
    }

    function _addChainlinkRelayer(
        string memory rateFeed,
        string memory description,
        address aggregator0,
        bool invert0
    ) internal {
        IChainlinkRelayer.ChainlinkAggregator[]
            memory aggregators = new IChainlinkRelayer.ChainlinkAggregator[](1);
        aggregators[0] = IChainlinkRelayer.ChainlinkAggregator({
            aggregator: aggregator0,
            invert: invert0
        });

        _addChainlinkRelayer(rateFeed, description, 0, aggregators);
    }

    function _addChainlinkRelayer(
        string memory rateFeed,
        string memory description,
        uint256 maxTimestampSpread,
        address aggregator0,
        bool invert0,
        address aggregator1,
        bool invert1
    ) internal {
        IChainlinkRelayer.ChainlinkAggregator[]
            memory aggregators = new IChainlinkRelayer.ChainlinkAggregator[](2);
        aggregators[0] = IChainlinkRelayer.ChainlinkAggregator({
            aggregator: aggregator0,
            invert: invert0
        });
        aggregators[1] = IChainlinkRelayer.ChainlinkAggregator({
            aggregator: aggregator1,
            invert: invert1
        });

        _addChainlinkRelayer(
            rateFeed,
            description,
            maxTimestampSpread,
            aggregators
        );
    }

    function _addChainlinkRelayer(
        string memory rateFeed,
        string memory description,
        uint256 maxTimestampSpread,
        IChainlinkRelayer.ChainlinkAggregator[] memory aggregators
    ) internal {
        address rateFeedId = getRateFeedIdFromString(rateFeed);
        require(
            _isRateFeed[rateFeedId],
            string.concat(rateFeed, " is not a registered rate feed")
        );
        _chainlinkRelayerRateFeedIds.push(rateFeedId);
        ChainlinkRelayerConfig storage relayer = _chainlinkRelayers[rateFeedId];
        relayer.rateFeedId = rateFeedId;
        relayer.rateFeed = rateFeed;
        relayer.rateFeedDescription = description;
        relayer.maxTimestampSpread = maxTimestampSpread;
        for (uint i = 0; i < aggregators.length; i++) {
            relayer.aggregators.push(aggregators[i]);
        }
    }

    function _setMockAggregatorSource(string memory network) internal {
        require(
            mockAggregatorSourceFork == 0,
            "Mock Aggregator Source already set"
        );
        mockAggregatorSourceFork = vm.createFork(network);
    }

    function _addMockAggregator(
        string memory description,
        address source
    ) internal {
        _mockAggregatorConfigs.push(
            MockAggregatorConfig({
                description: description,
                decimals: 0,
                initialReport: 0,
                source: source
            })
        );
    }

    function _addBreaker(
        BreakerType breakerType,
        uint256 defaultCooldownTime,
        uint256 defaultThreshold
    ) internal returns (bytes32 breakerId) {
        breakerId = keccak256(abi.encode(breakerType, _breakerIds.length));
        _breakerIds.push(breakerId);
        BreakerConfig storage breaker = _breakers[breakerId];
        breaker.breakerType = breakerType;
        breaker.defaultCooldownTime = defaultCooldownTime;
        breaker.defaultThreshold = defaultThreshold;
    }

    function _addToBreaker(
        bytes32 breakerId,
        string memory rateFeed,
        uint256 cooldown,
        uint256 threshold,
        uint256 smoothingFactor,
        uint256 referenceValue
    ) internal {
        BreakerConfig storage breaker = _breakers[breakerId];
        if (breaker.breakerType == BreakerType.Value) {
            require(
                smoothingFactor == 0,
                "ValueBreaker shouldn't have smoothing factor"
            );
            require(
                referenceValue > 0,
                "ValueBreaker should have reference value"
            );
        } else {
            require(
                smoothingFactor > 0,
                "MedianBreaker should have smoothing factor"
            );
            require(
                referenceValue == 0,
                "MedianBreaker should have reference value"
            );
        }
        breaker.rateFeedIds.push(getRateFeedIdFromString(rateFeed));
        breaker.cooldownTimes.push(cooldown);
        breaker.thresholds.push(threshold);
        breaker.smoothingFactors.push(smoothingFactor);
        breaker.referenceValues.push(referenceValue);
    }

    function _addExchange(
        string memory asset0,
        string memory asset1,
        string memory pricingModule,
        uint256 spread,
        string memory rateFeed,
        uint256 resetFrequency,
        uint256 stablePoolResetSize,
        ExchangeTrandingLimitsConfig memory tradingLimits
    ) internal {
        require(
            _isStableToken[asset0],
            string.concat(
                "MentoConfig: ",
                asset0,
                " is not a registered stableToken"
            )
        );
        require(
            _isStableToken[asset1] || _collateral[asset1] != address(0),
            string.concat(
                "MentoConfig: ",
                asset1,
                " is not a registered stableToken or collateral"
            )
        );
        address _asset0 = _resolveExchangeAsset(asset0);
        address _asset1 = _resolveExchangeAsset(asset1);
        address _pricingModule = lookup(pricingModule);
        if (
            _asset0 == address(0) ||
            _asset1 == address(0) ||
            _pricingModule == address(0)
        ) {
            console.log(
                string.concat(
                    "MentoConfig: Skipping pool ",
                    asset0,
                    "/",
                    asset1,
                    ": Could not resolve assets or pricing module"
                )
            );
            return;
        }
        _exchanges.push(
            ExchangeConfig({
                pool: IBiPoolManager.PoolExchange({
                    asset0: _asset0,
                    asset1: _asset1,
                    pricingModule: IPricingModule(_pricingModule),
                    bucket0: 0,
                    bucket1: 0,
                    lastBucketUpdate: 0,
                    config: IBiPoolManager.PoolConfig({
                        spread: FixidityLib.wrap(spread),
                        referenceRateFeedID: getRateFeedIdFromString(rateFeed),
                        referenceRateResetFrequency: resetFrequency,
                        minimumReports: 1,
                        stablePoolResetSize: stablePoolResetSize
                    })
                }),
                tradingLimits: tradingLimits
            })
        );
    }

    /// @dev we don't set the protocol fee recipient or the fee setter because
    ///      it will most likely need to be deployment-specific rather than
    ///      network-specific
    function _setDefaultFPMMParams(
        uint256 lpFee,
        uint256 protocolFee,
        uint256 rebalanceIncentive,
        uint256 rebalanceThresholdAbove,
        uint256 rebalanceThresholdBelow
    ) internal {
        _defaultFPMMParams = IFPMM.FPMMParams(
            lpFee,
            protocolFee,
            address(0),
            address(0),
            rebalanceIncentive,
            rebalanceThresholdAbove,
            rebalanceThresholdBelow
        );
    }

    function _addDeployedContract(
        string memory name,
        address contractAddress
    ) internal {
        _deployedContract[name] = contractAddress;
    }

    function _setRedemptionShortfallTolerance(uint256 tolerance) internal {
        _redemptionShortfallTolerance = tolerance;
    }

    function _addFPMM(
        string memory token0,
        string memory token1,
        address rateFeed,
        IFPMM.FPMMParams memory params,
        ReserveLiquidityStrategyPoolConfig memory rlsParams
    ) internal {
        address _fpmmImpl = lookup("FPMM:v3.0.0");
        address _oracleAdapter = lookupProxyOrFail("OracleAdapter");
        address _proxyAdmin = lookup("ProxyAdmin");
        address token0Address = _lookupTokenAddress(token0);
        address token1Address = _lookupTokenAddress(token1);

        FPMMConfig memory c;
        c.fpmmImplementation = _fpmmImpl;
        c.oracleAdapter = _oracleAdapter;
        c.proxyAdmin = _proxyAdmin;
        c.token0 = token0Address;
        c.token1 = token1Address;
        c.referenceRateFeedID = rateFeed;
        c.invertRateFeed = _shouldInvertRateFeed(token0Address, token1Address);
        c.params = params;
        c.rlsConfig = rlsParams;

        _fpmmConfigs.push(c);
    }
    

    function _lookupTokenAddress(string memory symbol) internal returns (address) {
        bool isStableToken = _isStableToken[symbol];
        bool isCollateral = isCollateralAsset(symbol);

        require(!isStableToken || !isCollateral, "Token is both stable and collateral");

        if (isStableToken) {
            return lookupProxyOrFail(symbol);
        } else {
            return _collateral[symbol];
        }
    }

    function _shouldInvertRateFeed(address token0, address token1) private returns (bool) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

        string memory token0Symbol = IERC20Metadata(token0).symbol();
        string memory token1Symbol = IERC20Metadata(token1).symbol();

        bool isFxPool = !isCollateralAsset(token0Symbol) && !isCollateralAsset(token1Symbol);

        if (isFxPool) {
            bool isToken0USDm = areStringsEqual(IERC20Metadata(token0).symbol(), "USDm");

            return isToken0USDm ? false : true;
        } else {
            bool isToken0Collateral = isCollateralAsset(token0Symbol);

            return isToken0Collateral ? false : true;
        }
    }

    function isCollateralAsset(string memory symbol) internal returns (bool) {
        return _collateral[symbol] != address(0);
    }

    function areStringsEqual(string memory a, string memory b) internal returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _resolveExchangeAsset(
        string memory symbol
    ) internal returns (address) {
        if (_collateral[symbol] != address(0)) {
            return _collateral[symbol];
        } else {
            return predictProxy(sender("deployer"), symbol);
        }
    }

    function _predict(
        string memory artifact,
        string memory label
    ) internal returns (address) {
        return sender("deployer").create3(artifact).setLabel(label).predict();
    }
}
