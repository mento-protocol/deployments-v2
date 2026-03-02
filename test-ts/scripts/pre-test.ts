import fs from "fs";
import path from "path";
import hre from "hardhat";
import { getDeployedContract, getRegistryAddress } from "../treb";
import {
  snapshot,
  setBalance,
  setERC20Balance,
  impersonate,
  stopImpersonating,
} from "../anvil";
import {
  contractAt,
  mintStableToken,
  drainWhale,
  refreshAllBiPoolOracles,
  refreshSortedOracles,
} from "../helpers";
import type { TestFixture } from "../fixture";

const FIXTURE_PATH = path.resolve(__dirname, "../../.treb/priv/test-fixture.json");

async function main() {
  console.log("pre-test: taking snapshot...");
  const snapshotId = await snapshot();

  // ── Contract addresses ──────────────────────────────────────────────
  console.log("pre-test: fetching contract addresses...");

  const fpmmFactory = await getDeployedContract("FPMMFactory");
  const router = await getDeployedContract("Router");
  const vpFactory = await getDeployedContract("VirtualPoolFactory");
  const biPoolManagerAddr = await getRegistryAddress("Proxy:BiPoolManager");
  const sortedOraclesAddr = await getRegistryAddress("Proxy:SortedOracles");
  const borrowerOps = await getDeployedContract("BorrowerOperations");
  const troveManager = await getDeployedContract("TroveManager");
  const stabilityPool = await getDeployedContract("StabilityPool");
  const hintHelpers = await getDeployedContract("HintHelpers");
  const systemParams = await getDeployedContract("SystemParams");
  const addressesRegistry = await getDeployedContract("AddressesRegistry");
  const reserveStrategy = await getDeployedContract("ReserveLiquidityStrategy");
  const cdpStrategy = await getDeployedContract("CDPLiquidityStrategy");

  // Mock aggregator
  const mockAggregatorAddr = await getRegistryAddress("MockChainlinkAggregator:GBPUSD");
  const mockAggregator = contractAt("MockChainlinkAggregator", mockAggregatorAddr);
  const mockAggregatorDecimals = Number(await mockAggregator.decimals());
  const originalPrice: bigint = await mockAggregator.savedAnswer();

  // FXPriceFeed proxy
  const priceFeedAddr = await getRegistryAddress("TransparentUpgradeableProxy:FXPriceFeedProxy:GBPm");
  const priceFeed = contractAt("FXPriceFeed", priceFeedAddr);
  const priceFeedRateFeedId: string = await priceFeed.rateFeedID();

  // BreakerBox
  const breakerBoxAddr = await getRegistryAddress("BreakerBox:v2.6.5");

  // ── Discover FPMMs ──────────────────────────────────────────────────
  console.log("pre-test: discovering FPMMs...");

  const fpmmAddresses: string[] = await fpmmFactory.deployedFPMMAddresses();
  let gbpmUsdmAddr = "";
  let usdcUsdmAddr = "";

  for (const addr of fpmmAddresses) {
    const fpmm = contractAt("FPMM", addr);
    const [t0, t1] = await Promise.all([fpmm.token0(), fpmm.token1()]);
    const [sym0, sym1] = await Promise.all([
      contractAt("ERC20", t0).symbol(),
      contractAt("ERC20", t1).symbol(),
    ]);
    if (`${sym0}/${sym1}` === "GBPm/USDm") gbpmUsdmAddr = addr;
    if (`${sym0}/${sym1}` === "USDC/USDm") usdcUsdmAddr = addr;
  }

  if (!gbpmUsdmAddr) throw new Error("GBPm/USDm FPMM not found");
  if (!usdcUsdmAddr) throw new Error("USDC/USDm FPMM not found");

  const fpmmGBPmUSDm = contractAt("FPMM", gbpmUsdmAddr);
  const fpmmUSDCUSDm = contractAt("FPMM", usdcUsdmAddr);

  const gbpmAddr: string = await fpmmGBPmUSDm.token0();
  const usdmAddr: string = await fpmmGBPmUSDm.token1();
  const usdcAddr: string = await fpmmUSDCUSDm.token0();
  const usdcDecimals = Number(await contractAt("ERC20", usdcAddr).decimals());
  const protocolFeeRecipient: string = await fpmmGBPmUSDm.protocolFeeRecipient();

  // Virtual pool addresses
  const vpAddresses: string[] = await vpFactory.getAllPools();

  // ── Trove data ──────────────────────────────────────────────────────
  console.log("pre-test: fetching trove data...");

  const boldAddr: string = await addressesRegistry.boldToken();
  const collAddr: string = await addressesRegistry.collToken();
  const collToken = contractAt("ERC20", collAddr);
  const collDecimals = Number(await collToken.decimals());
  const gasTokenAddr: string = await addressesRegistry.gasToken();

  const MCR: bigint = await systemParams.MCR();
  const MIN_DEBT: bigint = await systemParams.MIN_DEBT();
  const MIN_RATE: bigint = await systemParams.MIN_ANNUAL_INTEREST_RATE();
  const GAS_COMPENSATION: bigint = await systemParams.ETH_GAS_COMPENSATION();

  // System price: FXPriceFeed inverts GBP/USD -> USD/GBP in 18 decimals
  const systemPrice = 10n ** (18n + BigInt(mockAggregatorDecimals)) / originalPrice;

  // ── Accounts ────────────────────────────────────────────────────────
  console.log("pre-test: funding accounts...");

  const lpAddr = "0x" + "1".repeat(40);
  const traderAddr = "0x" + "2".repeat(40);

  const troveAccounts: string[] = [];
  for (let i = 0; i < 4; i++) {
    troveAccounts.push("0x" + "dead" + (i + 1).toString(16).padStart(36, "0"));
  }

  // Fund ETH balances
  const allAccounts = [lpAddr, traderAddr, ...troveAccounts];
  for (const addr of allAccounts) {
    await setBalance(addr, 10n ** 18n);
  }

  // Mint stable tokens for LP and trader
  await mintStableToken(usdmAddr, lpAddr, 100_000n * 10n ** 18n);
  await mintStableToken(usdmAddr, traderAddr, 100_000n * 10n ** 18n);
  await mintStableToken(gbpmAddr, lpAddr, 100_000n * 10n ** 18n);
  await mintStableToken(gbpmAddr, traderAddr, 100_000n * 10n ** 18n);

  // Drain USDC from whale
  const usdcWhale = "0x28D450238851C78F320FA8cc21b73E35a7e3E5Bc";
  await drainWhale(usdcAddr, usdcWhale, lpAddr, 100_000n * 10n ** BigInt(usdcDecimals));
  await drainWhale(usdcAddr, usdcWhale, traderAddr, 100_000n * 10n ** BigInt(usdcDecimals));

  // Mint collateral (USDm) and fund CELO (gas token) for trove accounts
  const collAmount = 100_000n * 10n ** BigInt(collDecimals);
  for (const addr of troveAccounts) {
    await mintStableToken(collAddr, addr, collAmount);
    await setERC20Balance(gasTokenAddr, addr, 100n * 10n ** 18n);
  }

  // ── Refresh oracles ─────────────────────────────────────────────────
  console.log("pre-test: refreshing oracles...");

  // Refresh all BiPool oracles (for FPMM virtual pool swaps)
  await refreshAllBiPoolOracles(biPoolManagerAddr, sortedOraclesAddr);

  // Refresh mock aggregator oracle (for trove tests)
  const aggOwner: string = await mockAggregator.owner();
  await impersonate(aggOwner);
  await setBalance(aggOwner, 10n ** 18n);
  const ownerSigner = await hre.ethers.getSigner(aggOwner);
  const block = await hre.ethers.provider.getBlock("latest");
  await contractAt("MockChainlinkAggregator", mockAggregatorAddr, ownerSigner)
    .report(originalPrice, block!.timestamp);
  await stopImpersonating(aggOwner);

  // Refresh SortedOracles for the price feed rate feed
  await refreshSortedOracles(sortedOraclesAddr, priceFeedRateFeedId);

  // ── Write fixture ───────────────────────────────────────────────────
  console.log("pre-test: writing fixture...");

  const fixture: TestFixture = {
    snapshotId,
    contracts: {
      fpmmFactory: fpmmFactory.target as string,
      router: router.target as string,
      vpFactory: vpFactory.target as string,
      biPoolManager: biPoolManagerAddr,
      sortedOracles: sortedOraclesAddr,
      borrowerOps: borrowerOps.target as string,
      troveManager: troveManager.target as string,
      stabilityPool: stabilityPool.target as string,
      hintHelpers: hintHelpers.target as string,
      systemParams: systemParams.target as string,
      addressesRegistry: addressesRegistry.target as string,
      mockAggregator: mockAggregatorAddr,
      priceFeed: priceFeedAddr,
      breakerBox: breakerBoxAddr,
      reserveStrategy: reserveStrategy.target as string,
      cdpStrategy: cdpStrategy.target as string,
    },
    fpmm: {
      gbpmUsdm: gbpmUsdmAddr,
      usdcUsdm: usdcUsdmAddr,
      gbpmAddr,
      usdmAddr,
      usdcAddr,
      usdcDecimals,
      protocolFeeRecipient,
      vpAddresses,
    },
    trove: {
      boldAddr,
      collAddr,
      collDecimals,
      gasTokenAddr,
      MCR: "0x" + MCR.toString(16),
      MIN_DEBT: "0x" + MIN_DEBT.toString(16),
      MIN_RATE: "0x" + MIN_RATE.toString(16),
      GAS_COMPENSATION: "0x" + GAS_COMPENSATION.toString(16),
      mockAggregatorDecimals,
      originalPrice: "0x" + originalPrice.toString(16),
      systemPrice: "0x" + systemPrice.toString(16),
      priceFeedRateFeedId,
    },
    accounts: {
      lp: lpAddr,
      trader: traderAddr,
      troveAccounts,
    },
  };

  // Ensure directory exists
  const dir = path.dirname(FIXTURE_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(FIXTURE_PATH, JSON.stringify(fixture, null, 2));
  console.log(`pre-test: fixture written to ${FIXTURE_PATH}`);
  console.log("pre-test: done.");
}

main().catch((err) => {
  console.error("pre-test failed:", err);
  process.exit(1);
});
