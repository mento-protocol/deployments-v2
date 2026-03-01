# PRD: V3 Upgrade Integration Tests

## Introduction

After the Mento Protocol v2 → v3 upgrade (a 7-script pipeline), there are no integration tests that verify the final on-chain state or that key user flows work correctly. The existing per-script `postChecks()` verify deployment-time state but don't test cross-script interactions, user-facing functionality, or edge cases. This PRD defines a comprehensive integration test suite that validates both the final protocol state and all critical user flows after the full upgrade has been applied.

## Goals

- Verify the complete on-chain state after all 7 upgrade scripts have executed
- Test all critical user flows: swaps (FPMM + Router + VirtualPool), rebalancing (Reserve + CDP strategies), CDP operations (trove management, stability pool), stable token minting/burning, and oracle/breaker behavior
- Support two execution modes: (a) forking a chain where the upgrade already happened, and (b) running the full 7-script upgrade locally on an Anvil fork as test setup
- Cover everything the existing `postChecks()` already verify, plus extended cases and user flows
- Keep the existing `postChecks()` in the deployment scripts untouched

## User Stories

### US-001: Create base test harness with dual execution modes
**Description:** As a developer, I want a base test contract that supports both "fork an upgraded chain" and "run the full upgrade locally" modes so that I can test against either environment.

**Acceptance Criteria:**
- [ ] Create `test/integration/V3IntegrationBase.t.sol` abstract contract inheriting from `forge-std/Test.sol`, `ProxyHelper`, and `ConfigHelper`
- [ ] Implement a `_runFullUpgrade()` helper that executes all 7 scripts in order using the Treb/Senders framework on an Anvil fork
- [ ] Implement a `_forkUpgradedChain()` helper that forks a chain where the upgrade is already live
- [ ] Use environment variables (e.g. `INTEGRATION_MODE=local|fork`, `FORK_URL`) to select mode
- [ ] `setUp()` resolves all key contract addresses (FPMMFactory, OracleAdapter, Router, ReserveV2, CDPLiquidityStrategy, etc.) from the registry after setup
- [ ] Base contract exposes helper methods for common operations (mint tokens, perform swaps, provide liquidity)
- [ ] Typecheck/lint passes (`forge build`)

### US-002: Verify proxy and implementation state
**Description:** As a developer, I want to verify that all proxies point to the correct implementations and that implementation contracts cannot be initialized directly, so that the upgrade is secure.

**Acceptance Criteria:**
- [ ] Test that OracleAdapter, FPMMFactory, FactoryRegistry, ReserveV2, ReserveLiquidityStrategy, CDPLiquidityStrategy proxies all point to their v3.0.0 implementations
- [ ] Test that all implementation contracts revert on `initialize()` (initialization disabled)
- [ ] Test that StableTokenV3 proxy implementation is upgraded correctly for each migrated token
- [ ] Test that ProxyAdmin is set correctly on all FPMM pool proxies
- [ ] Typecheck passes

### US-003: Verify ownership and access control
**Description:** As a developer, I want to confirm all contracts are owned by the correct multisig/migration owner and that role-based access control is configured correctly.

**Acceptance Criteria:**
- [ ] Test ownership of: OracleAdapter, FPMMFactory, FactoryRegistry, VirtualPoolFactory, ReserveV2, ReserveLiquidityStrategy, CDPLiquidityStrategy
- [ ] Test that non-owners cannot call protected functions (e.g. `transferOwnership`, `addBreaker`, `registerStableAsset`)
- [ ] Test StableTokenV3 minter/burner/operator roles: Liquity contracts (BorrowerOperations, ActivePool, CollateralRegistry, TroveManager, StabilityPool) have correct roles; Broker permissions are removed for CDP-migrated tokens
- [ ] Typecheck passes

### US-004: Verify OracleAdapter and BreakerBox configuration
**Description:** As a developer, I want to verify the oracle infrastructure is correctly wired — OracleAdapter reads from SortedOracles, BreakerBox has MarketHoursBreaker enabled on all FX feeds.

**Acceptance Criteria:**
- [ ] Test OracleAdapter.sortedOracles() == SortedOracles proxy
- [ ] Test OracleAdapter.breakerBox() == BreakerBox address
- [ ] Test OracleAdapter.marketHoursBreaker() == deployed MarketHoursBreaker
- [ ] Test BreakerBox.isBreaker(marketHoursBreaker) == true with trading mode 3
- [ ] Test MarketHoursBreaker is enabled on every FX rate feed ID from config
- [ ] Test that OracleAdapter returns valid FX rates for all configured feeds
- [ ] Typecheck passes

### US-005: Verify FPMMFactory and FactoryRegistry state
**Description:** As a developer, I want to verify the factory infrastructure is correctly initialized and that pools can be looked up.

**Acceptance Criteria:**
- [ ] Test FPMMFactory.oracleAdapter() == OracleAdapter proxy
- [ ] Test FPMMFactory.proxyAdmin() == ProxyAdmin
- [ ] Test FPMMFactory default params match config (lpFee, protocolFee, protocolFeeRecipient, feeSetter, rebalanceIncentive, rebalanceThresholdAbove, rebalanceThresholdBelow)
- [ ] Test FPMMFactory.isRegisteredImplementation(fpmmImpl) == true
- [ ] Test FactoryRegistry.fallbackPoolFactory() == FPMMFactory
- [ ] Test FactoryRegistry.isPoolFactoryApproved(fpmmFactory) == true
- [ ] Test FactoryRegistry.isPoolFactoryApproved(virtualPoolFactory) == true (if applicable)
- [ ] Typecheck passes

### US-006: Verify Router configuration
**Description:** As a developer, I want to verify the Router is correctly wired to the FactoryRegistry and FPMMFactory.

**Acceptance Criteria:**
- [ ] Test Router.factoryRegistry() == FactoryRegistry proxy
- [ ] Test Router.defaultFactory() == FPMMFactory proxy
- [ ] Typecheck passes

### US-007: Verify ReserveV2 configuration
**Description:** As a developer, I want to verify ReserveV2 has the correct asset registrations and spender permissions.

**Acceptance Criteria:**
- [ ] Test ReserveSafe is registered as other reserve address
- [ ] Test ReserveSafe is registered as reserve manager spender
- [ ] Test ReserveLiquidityStrategy is registered as liquidity strategy spender
- [ ] Test all stable assets from CDP migrations are registered as stable assets
- [ ] Test all collateral assets from CDP migrations are registered as collateral assets
- [ ] Typecheck passes

### US-008: Verify FPMM pool state
**Description:** As a developer, I want to verify each deployed FPMM pool has correct tokens, oracle config, params, and initial liquidity.

**Acceptance Criteria:**
- [ ] For each FPMM pool from config: verify token0/token1 match sorted pair
- [ ] Verify referenceRateFeedID and invertRateFeed match config
- [ ] Verify oracleAdapter points to OracleAdapter proxy
- [ ] Verify FPMM params (lpFee, protocolFee, etc.) match config or factory defaults
- [ ] Verify pool has non-zero reserves (r0 > 0, r1 > 0)
- [ ] Verify pool has non-zero LP token totalSupply
- [ ] Verify factory.isPool(fpmmProxy) == true
- [ ] Typecheck passes

### US-009: Verify VirtualPool deployment
**Description:** As a developer, I want to verify virtual pools were deployed for all configured exchange pairs and that their tokens match.

**Acceptance Criteria:**
- [ ] For each BiPoolManager exchange marked `createVirtual` in config: verify a virtual pool exists
- [ ] Verify virtual pool token0/token1 match the underlying exchange pair (sorted)
- [ ] Verify VirtualPoolFactory.getPool(token0, token1) returns the deployed address
- [ ] Typecheck passes

### US-010: Verify CDP migration state
**Description:** As a developer, I want to verify the CDP migration is complete — V2 exchange destroyed, Liquity roles set, CDP strategy configured, reserve trove active.

**Acceptance Criteria:**
- [ ] Test the old V2 BiPoolManager exchange for the migrated pair no longer exists
- [ ] Test Broker is NOT a minter/burner on the CDP-migrated debt token
- [ ] Test all Liquity contracts have correct minter/burner/operator roles (per MigrateStableToCDP._checkDebtTokenRoles)
- [ ] Test CDPLiquidityStrategy is enabled as liquidity strategy on the FPMM
- [ ] Test FPMM is registered as a pool on CDPLiquidityStrategy
- [ ] Test CDPConfig (stabilityPool, collateralRegistry, stabilityPoolPercentage, maxIterations) matches config
- [ ] Test pool config (cooldown, incentives, protocolFeeRecipient) matches config
- [ ] Test FXPriceFeed.rateFeedID matches config
- [ ] Test reserve trove is active with correct interest rate
- [ ] Test reserve trove NFT is owned by reserveTroveManager
- [ ] Test reserve trove debt >= debt token total supply
- [ ] Test ReserveTroveFactory temporary permissions are cleaned up (not minter/burner)
- [ ] Typecheck passes

### US-011: Test FPMM swap flow
**Description:** As a user, I want to swap tokens through an FPMM pool directly so that I can exchange stablecoins.

**Acceptance Criteria:**
- [ ] Test swapping token0 → token1 on an FPMM: amountOut > 0, balances update correctly
- [ ] Test swapping token1 → token0 on an FPMM: amountOut > 0, balances update correctly
- [ ] Test getAmountOut returns accurate preview matching actual swap output
- [ ] Test swap reverts with zero input amount
- [ ] Test swap updates reserves correctly after execution
- [ ] Typecheck passes

### US-012: Test Router swap flow
**Description:** As a user, I want to swap tokens through the Router so that I get optimal routing across pools.

**Acceptance Criteria:**
- [ ] Test Router.swap() routes through the correct FPMM pool
- [ ] Test swap output matches direct FPMM swap (minus any additional routing cost)
- [ ] Test Router correctly resolves pool via FactoryRegistry → FPMMFactory
- [ ] Typecheck passes

### US-013: Test ReserveLiquidityStrategy rebalancing
**Description:** As a keeper, I want to trigger rebalancing on FPMM pools via the ReserveLiquidityStrategy so that pool prices stay close to oracle prices.

**Acceptance Criteria:**
- [ ] Test: after a large one-sided swap pushes the pool out of balance, calling `rebalance()` reduces the price difference
- [ ] Test: rebalance correctly mints/burns debt tokens and moves collateral from ReserveV2
- [ ] Test: rebalance respects cooldown — calling too soon after a rebalance reverts
- [ ] Test: rebalance is a no-op (or reverts) when pool is already within threshold
- [ ] Test: reserves on ReserveV2 change by expected amounts after rebalance
- [ ] Typecheck passes

### US-014: Test CDPLiquidityStrategy rebalancing
**Description:** As a keeper, I want to trigger rebalancing on CDP-backed FPMM pools via the CDPLiquidityStrategy so that pool prices stay aligned with the oracle.

**Acceptance Criteria:**
- [ ] Test: after a large swap imbalances the CDP-backed FPMM, calling `rebalance()` reduces price difference
- [ ] Test: rebalance interacts correctly with the Liquity StabilityPool and CollateralRegistry
- [ ] Test: rebalance respects cooldown
- [ ] Test: rebalance is a no-op or reverts when pool is within threshold
- [ ] Typecheck passes

### US-015: Test stable token minting and burning
**Description:** As a protocol, I want to verify that the correct contracts can mint and burn stable tokens and unauthorized callers cannot.

**Acceptance Criteria:**
- [ ] Test: Broker can mint/burn on non-CDP-migrated StableTokenV3 tokens
- [ ] Test: Liquity BorrowerOperations/ActivePool can mint on CDP-migrated tokens
- [ ] Test: Liquity CollateralRegistry/BorrowerOperations/TroveManager/StabilityPool can burn on CDP-migrated tokens
- [ ] Test: unauthorized address cannot mint or burn (reverts)
- [ ] Test: StabilityPool can use operator role (transferFrom without approval) on CDP-migrated tokens
- [ ] Typecheck passes

### US-016: Test oracle and breaker behavior
**Description:** As a developer, I want to verify that the MarketHoursBreaker correctly halts trading outside FX market hours and that the OracleAdapter respects breaker state.

**Acceptance Criteria:**
- [ ] Test: during FX market hours, OracleAdapter returns valid rates
- [ ] Test: outside FX market hours (if toggleable breaker), the breaker triggers and OracleAdapter reports invalid/halted
- [ ] Test: BreakerBox correctly reports trading mode when breaker triggers
- [ ] Typecheck passes

### US-017: Test liquidity provision and removal on FPMM
**Description:** As a liquidity provider, I want to add and remove liquidity from FPMM pools.

**Acceptance Criteria:**
- [ ] Test: providing liquidity (mint) increases reserves and gives LP tokens
- [ ] Test: removing liquidity (burn LP) decreases reserves and returns proportional tokens
- [ ] Test: LP token balance reflects share of pool
- [ ] Typecheck passes

### US-018: Test reserve trove operations
**Description:** As a developer, I want to verify the reserve trove can be managed and that its collateralization remains valid.

**Acceptance Criteria:**
- [ ] Test: reserve trove is active and has correct collateral and debt
- [ ] Test: trove collateralization ratio meets the configured minimum
- [ ] Test: trove accrues interest over time (warp forward, check debt increases)
- [ ] Typecheck passes

## Functional Requirements

- FR-1: All tests must inherit from a shared `V3IntegrationBase` that handles test environment setup
- FR-2: The base contract must support `INTEGRATION_MODE=local` (run all 7 upgrade scripts on Anvil fork) and `INTEGRATION_MODE=fork` (fork an already-upgraded chain)
- FR-3: State verification tests must cover every check in the existing `postChecks()` functions across all 7 scripts, plus extended checks
- FR-4: Functional tests must use realistic token amounts and oracle prices from the chain config
- FR-5: Tests must use `deal()` / Anvil helpers to fund test accounts — not rely on any pre-funded addresses
- FR-6: Each test file should be runnable independently with `forge test --match-contract <ContractName>`
- FR-7: Tests must not modify the existing deployment scripts or their `postChecks()`

## Non-Goals

- No gas optimization benchmarking
- No fuzz testing or invariant testing (can be added later)
- No frontend/UI testing
- No load/stress testing for high-throughput scenarios
- No governance flow testing (timelock, voting)
- No testing of the Locking contract or MENTO token mechanics
- No cross-chain testing

## Technical Considerations

- **Foundry test framework**: All tests use `forge-std/Test.sol` with `vm` cheatcodes
- **Registry lookups**: Use `lookup()` / `lookupOrFail()` from `ProxyHelper` (inherited via `TrebScript`) for address resolution
- **Config loading**: Use `Config.get()` to load network-specific config matching the forked chain
- **Anvil helpers**: Use `script/helpers/Anvil.sol` for `deal()`-style token balance manipulation
- **Time manipulation**: Use `vm.warp()` for cooldown and interest accrual tests
- **Sender impersonation**: Use `vm.prank()` / `vm.startPrank()` to simulate calls from owner, keeper, or user accounts
- **File organization**: `test/integration/` directory with one file per logical test group

### Proposed File Structure

```
test/integration/
├── V3IntegrationBase.t.sol          # Base contract, setup, helpers
├── StateVerification.t.sol          # US-002 through US-010: all state checks
├── CDPMigrationVerification.t.sol   # US-010: CDP-specific state
├── FPMMSwap.t.sol                   # US-011: direct FPMM swaps
├── RouterSwap.t.sol                 # US-012: Router-based swaps
├── RebalanceReserve.t.sol           # US-013: ReserveLiquidityStrategy
├── RebalanceCDP.t.sol               # US-014: CDPLiquidityStrategy
├── StableTokenRoles.t.sol           # US-015: mint/burn/operator access
├── OracleBreaker.t.sol              # US-016: oracle + breaker behavior
├── LiquidityProvision.t.sol         # US-017: LP mint/burn
└── ReserveTrove.t.sol               # US-018: trove state + accrual
```

## Success Metrics

- All integration tests pass on an Anvil fork of Celo Sepolia after running the 7-script upgrade
- All integration tests pass when forking an already-upgraded testnet
- Tests catch regressions: intentionally breaking one script's config causes at least one test failure
- Full test suite runs in under 5 minutes on CI

## Open Questions

- Which specific chain/network should be the primary target for integration tests? (Celo Sepolia testnet vs. Celo mainnet)
    - Answer both i want tthe script to be able to run against any deployment e.g celo mainnet, celo sepolia or a deployment on an anvil fork. the test scripts should fetch the deployment addresses by doing lookups on the anvil registry the same way the deployment scripts are doing this. 
- Should we parameterize tests to run across multiple stable tokens (cUSD, cEUR, etc.) or test one representative token per category?
    -  yes they should run the tests against what ever is deployed on the network its is pointed to. this can be fetched from the treb registry via lookups as well as fetching pools/exchanges from the registries
- Are there specific edge cases from past incidents that should be explicitly tested?
    - Not sure to what extend this is covered already but i want it to also cover the CDP functionalities e.g openeing troves providing to the StabilityPool, liquidating troves, collecting interets etc.  
- For the local upgrade mode, does `SetupLocalFork.s.sol` need to be run first (to replace GoldToken with MockCELO, etc.) before the 7 upgrade scripts?
    - yes 
