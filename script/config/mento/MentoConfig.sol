// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from "forge-std/console2.sol";
import {TrebScript} from "treb-sol/src/TrebScript.sol";
import {Senders} from "lib/treb-sol/src/internal/sender/Senders.sol";
import {Deployer} from "treb-sol/src/internal/sender/Deployer.sol";

import {ProxyHelper} from "../../helpers/ProxyHelper.sol";
import {IMentoConfig, BreakerType, IBiPoolManager, ITradingLimits, IPricingModule, FixidityLib} from "../IMentoConfig.sol";
import {AggregatorV3Interface} from "lib/mento-core/lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

import {IChainlinkRelayer} from "lib/mento-core/contracts/interfaces/IChainlinkRelayer.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IFPMM} from "mento-core/interfaces/IFPMM.sol";

struct CoreAggregators {
    address celoUsd;
    address ethUsd;
    address usdcUsd;
    address usdtUsd;
    address eurcUsd;
}

struct FxAggregators {
    address eur;
    address brl;
    address xof;
    address kes;
    address php;
    address cop;
    address ghs;
    address gbp;
    address zar;
    address cad;
    address aud;
    address chf;
    address jpy;
    address ngn;
}

struct Collaterals {
    address usdc;
    address axlUsdc;
    address axlEuroc;
    address usdt;
    address celo;
}

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
    mapping(string rateFeedName => address rateFeedId) internal _rateFeedIdByName;
    mapping(address rateFeedId => ChainlinkRelayerConfig)
        internal _chainlinkRelayers;
    mapping(string symbol => address) internal _collateral;
    mapping(string symbol => bool) internal _isStableToken;
    mapping(address token => bool) internal _isAddressStableToken;
    mapping(address token => bool) internal _isAddressCollateralToken;
    mapping(bytes32 breakerId => BreakerConfig) _breakers;
    bytes32[] _breakerIds;

    mapping(string symbol => uint8) internal _tokenDecimals;

    FPMMConfig[] internal _fpmmConfigs;

    IFPMM.FPMMParams internal _defaultFPMMParams;
    /// @dev pairKey is for example "USDC/USDm" and it will be duplicated as "USDm/USDC"
    mapping(string pairKey => IFPMM.FPMMParams) internal _fpmmParams;
    uint256 internal _redemptionShortfallTolerance;

    uint256 public baseFork;
    uint256 public mockAggregatorSourceFork;

    mapping(string token => CDPMigrationConfig) _cdpMigrationConfig;

    // ========== Constructor ==========

    constructor() {
        _initialize();
        baseFork = vm.createFork(vm.envString("NETWORK"));
        vm.selectFork(baseFork);
    }

    // ========== Abstract Functions ==========

    function _initialize() internal virtual;

    // ========== View Functions ==========

    function getCDPMigrationConfig(string calldata token) external view returns (CDPMigrationConfig memory config) {
        return _cdpMigrationConfig[token];
    }

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

    function getExchangeConfig(
        address asset0,
        address asset1,
        address pricingModule
    ) public view returns (ExchangeConfig memory config, bool found) {
        for (uint i = 0; i < _exchanges.length; i++) {
            ExchangeConfig storage ex = _exchanges[i];
            bool assetsMatch = (ex.pool.asset0 == asset0 &&
                ex.pool.asset1 == asset1) ||
                (ex.pool.asset0 == asset1 && ex.pool.asset1 == asset0);
            if (
                assetsMatch &&
                address(ex.pool.pricingModule) == pricingModule
            ) {
                return (
                    abi.decode(abi.encode(ex), (ExchangeConfig)),
                    true
                );
            }
        }
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

    // ========== Internal Helper Functions ==========

    function _addStableToken(
        string memory currency,
        string memory symbol,
        string memory name
    ) internal {
        _isStableToken[symbol] = true;
        _isAddressStableToken[_lookupTokenAddress(symbol)] = true;
        _symbolForCurrency[currency] = symbol;
        _tokenDecimals[symbol] = 18;
        _tokens.push(
            TokenConfig({symbol: symbol, name: name, currency: currency})
        );
    }

    function _addCollateral(string memory symbol, address addy, uint8 decimals) internal {
        _isAddressCollateralToken[addy] = true;
        _collateralAssets.push(addy);
        _collateral[symbol] = addy;
        _tokenDecimals[symbol] = decimals;
    }

    function _addRateFeed(string memory rateFeed) internal {
        _addRateFeed(rateFeed, getRateFeedIdFromString(rateFeed));
    }

    function _addRateFeed(string memory rateFeed, address rateFeedId) internal {
        _isRateFeed[rateFeedId] = true;
        _rateFeedIdByName[rateFeed] = rateFeedId;
        _rateFeeds.push(RateFeed({rateFeed: rateFeed, rateFeedId: rateFeedId}));
    }

    function _getRateFeedId(string memory rateFeed) internal view returns (address) {
        address id = _rateFeedIdByName[rateFeed];
        require(id != address(0), string.concat(rateFeed, " is not registered as a rate feed."));
        return id;
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
        address depId = _getRateFeedId(dependency);
        _addRateFeedDependency(rateFeedId, depId);
    }

    function _addRateFeedDependency(
        string memory rateFeed,
        string memory dependency
    ) internal {
        _addRateFeedDependency(_getRateFeedId(rateFeed), _getRateFeedId(dependency));
    }

    function _addRateFeed(
        string memory rateFeed,
        string[] memory dependencies
    ) internal {
        _addRateFeed(rateFeed);
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
        address rateFeedId = _getRateFeedId(rateFeed);
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

    /// @notice Register a mock aggregator and return its deterministic address.
    function _mockAggregator(string memory label, address source) internal returns (address) {
        _addMockAggregator(label, source);
        return _predict("MockChainlinkAggregator", label);
    }

    /// @notice Register a mock collateral and return its deterministic address.
    function _registerMockCollateral(string memory symbol, uint8 decimals) internal returns (address) {
        address addy = lookup(string.concat("MockERC20:", symbol));
        if (addy == address(0)) {
            addy = _predict("MockERC20", symbol);
        }
        _mockCollateralAssets.push(symbol);
        _tokenDecimals[symbol] = decimals;
        return addy;
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
        breaker.rateFeedIds.push(_getRateFeedId(rateFeed));
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
        ExchangeTrandingLimitsConfig memory tradingLimits,
        bool createVirtual
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
        IBiPoolManager.PoolConfig memory poolConfig = IBiPoolManager.PoolConfig({
            spread: FixidityLib.wrap(spread),
            referenceRateFeedID: _getRateFeedId(rateFeed),
            referenceRateResetFrequency: resetFrequency,
            minimumReports: 1,
            stablePoolResetSize: stablePoolResetSize
        });
        _exchanges.push(
            ExchangeConfig({
                pool: IBiPoolManager.PoolExchange({
                    asset0: _asset0,
                    asset1: _asset1,
                    pricingModule: IPricingModule(_pricingModule),
                    bucket0: 0,
                    bucket1: 0,
                    lastBucketUpdate: 0,
                    config: poolConfig
                }),
                tradingLimits: tradingLimits,
                createVirtual: createVirtual
            })
        );
    }

    function _addFPMM(
        string memory debt,
        string memory collateral,
        address rateFeed,
        IFPMM.FPMMParams memory params,
        TokenLimits memory debtLimits,
        TokenLimits memory collateralLimits,
        ReserveLiquidityStrategyPoolConfig memory rlsParams
    ) internal {
        address debtAddress = _lookupTokenAddress(debt);
        address collateralAddress = _lookupTokenAddress(collateral);

        // Sort by address to determine token0/token1
        bool debtIsToken0 = debtAddress < collateralAddress;
        address token0Address = debtIsToken0 ? debtAddress : collateralAddress;
        address token1Address = debtIsToken0 ? collateralAddress : debtAddress;

        FPMMConfig memory c;
        c.fpmmImplementation = lookup("FPMM:v3.0.0");
        c.oracleAdapter = lookupProxy("OracleAdapter");
        c.proxyAdmin = lookup("ProxyAdmin");
        c.token0 = token0Address;
        c.token1 = token1Address;
        c.referenceRateFeedID = rateFeed;
        c.invertRateFeed = _shouldInvertRateFeed(token0Address, token1Address);
        c.params = params;
        c.tradingLimits = _buildFPMMTradingLimits(debt, collateral, debtIsToken0, debtLimits, collateralLimits);
        c.rlsConfig = rlsParams;

        _fpmmConfigs.push(c);
    }

    function _buildFPMMTradingLimits(
        string memory debt,
        string memory collateral,
        bool debtIsToken0,
        TokenLimits memory debtLimits,
        TokenLimits memory collateralLimits
    ) private view returns (FPMMTradingLimitsConfig memory) {
        uint256 debtScale = 10 ** _tokenDecimals[debt];
        uint256 collateralScale = 10 ** _tokenDecimals[collateral];

        TokenLimits memory scaledDebt = TokenLimits(
            debtLimits.limit0 * debtScale,
            debtLimits.limit1 * debtScale
        );
        TokenLimits memory scaledCollateral = TokenLimits(
            collateralLimits.limit0 * collateralScale,
            collateralLimits.limit1 * collateralScale
        );

        return FPMMTradingLimitsConfig({
            token0Limit0: debtIsToken0 ? scaledDebt.limit0 : scaledCollateral.limit0,
            token0Limit1: debtIsToken0 ? scaledDebt.limit1 : scaledCollateral.limit1,
            token1Limit0: debtIsToken0 ? scaledCollateral.limit0 : scaledDebt.limit0,
            token1Limit1: debtIsToken0 ? scaledCollateral.limit1 : scaledDebt.limit1
        });
    }
    

    function _lookupTokenAddress(string memory symbol) internal view returns (address) {
        bool isStable = _isStableToken[symbol];
        bool isCollateral = isCollateralAsset(symbol);

        require(!isStable || !isCollateral, "Token is both stable and collateral");
        require(isStable || isCollateral, string.concat("Token not found: ", symbol));

        if (isStable) {
            return lookupProxyOrFail(symbol);
        } else {
            return _collateral[symbol];
        }
    }

    function _shouldInvertRateFeed(address token0, address token1) private view returns (bool) {
        bool isFxPool = isStableToken(token0) && isStableToken(token1);

        if (isFxPool) {
            bool isToken0USDm = areStringsEqual(IERC20Metadata(token0).symbol(), "USDm");
            return isToken0USDm ? true : false;
        } else {
            bool isToken0Collateral = isCollateralAsset(token0);
            return isToken0Collateral ? false : true;
        }
    }

    function isCollateralAsset(string memory symbol) internal view returns (bool) {
        return _collateral[symbol] != address(0);
    }

    function isCollateralAsset(address token) internal view returns (bool) {
        return _isAddressCollateralToken[token];
    }

    function isStableToken(address token) internal view returns (bool) {
        return _isAddressStableToken[token];
    }

    function areStringsEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function _resolveExchangeAsset(
        string memory symbol
    ) internal returns (address) {
        if (_collateral[symbol] != address(0)) {
            return _collateral[symbol];
        } else {
            address proxy = lookupProxy(symbol);
            if (proxy != address(0)) {
                return proxy;
            }
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
