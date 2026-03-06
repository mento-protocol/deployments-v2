import fs from "fs";
import path from "path";
import { getDeployedContract, getRegistryAddress } from "../helpers/treb";
import { contractAt, isCelo } from "../helpers/helpers";
import { FIXTURE_PATH } from "../helpers/fixture";
import type { TestFixture } from "../helpers/fixture";

async function main() {
  const celo = await isCelo();

  // ── Contract addresses ──────────────────────────────────────────────
  console.log("pre-test: fetching contract addresses...");

  const fpmmFactory = await getDeployedContract("FPMMFactory");
  const router = await getDeployedContract("Router");
  const sortedOracles = await getDeployedContract("SortedOracles");
  const sortedOraclesAddr = sortedOracles.target as string;
  const breakerBoxAddr = await getRegistryAddress("BreakerBox:v2.6.5");
  const reserveStrategy = await getDeployedContract("ReserveLiquidityStrategy");

  // Celo-only contracts
  let vpFactory: any = undefined;
  let biPoolManagerAddr: string | undefined;
  let borrowerOps: any = undefined;
  let troveManager: any = undefined;
  let stabilityPool: any = undefined;
  let hintHelpers: any = undefined;
  let systemParams: any = undefined;
  let addressesRegistry: any = undefined;
  let mockAggregatorAddr: string | undefined;
  let mockAggregatorDecimals: number | undefined;
  let originalPrice: bigint | undefined;
  let priceFeedAddr: string | undefined;
  let priceFeedRateFeedId: string | undefined;
  let cdpStrategy: any = undefined;

  if (celo) {
    vpFactory = await getDeployedContract("VirtualPoolFactory");
    biPoolManagerAddr = await getRegistryAddress("Proxy:BiPoolManager");
    borrowerOps = await getDeployedContract("BorrowerOperations");
    troveManager = await getDeployedContract("TroveManager");
    stabilityPool = await getDeployedContract("StabilityPool");
    hintHelpers = await getDeployedContract("HintHelpers");
    systemParams = await getDeployedContract("SystemParams");
    addressesRegistry = await getDeployedContract("AddressesRegistry");
    cdpStrategy = await getDeployedContract("CDPLiquidityStrategy");

    mockAggregatorAddr = await getRegistryAddress("MockChainlinkAggregator:GBPUSD");
    const mockAggregator = contractAt("MockChainlinkAggregator", mockAggregatorAddr);
    mockAggregatorDecimals = Number(await mockAggregator.decimals());
    originalPrice = await mockAggregator.savedAnswer();

    priceFeedAddr = await getRegistryAddress("TransparentUpgradeableProxy:FXPriceFeedProxy:GBPm");
    const priceFeed = contractAt("FXPriceFeed", priceFeedAddr);
    priceFeedRateFeedId = await priceFeed.rateFeedID();
  }

  // ── Discover FPMMs ──────────────────────────────────────────────────
  console.log("pre-test: discovering FPMMs...");

  const fpmmAddresses: string[] = await fpmmFactory.deployedFPMMAddresses();
  let gbpmUsdmAddr: string | undefined;
  let usdcUsdmAddr: string | undefined;
  let gbpmAddr: string | undefined;
  let usdmAddr: string | undefined;
  let usdcAddr = "";
  let usdcDecimals = 6;
  let protocolFeeRecipient = "";

  for (const addr of fpmmAddresses) {
    const fpmm = contractAt("FPMM", addr);
    const [t0, t1] = await Promise.all([fpmm.token0(), fpmm.token1()]);
    const [sym0, sym1] = await Promise.all([
      contractAt("ERC20", t0).symbol(),
      contractAt("ERC20", t1).symbol(),
    ]);

    if (protocolFeeRecipient === "") {
      protocolFeeRecipient = await fpmm.protocolFeeRecipient();
    }

    if (`${sym0}/${sym1}` === "GBPm/USDm") {
      gbpmUsdmAddr = addr;
      gbpmAddr = t0;
      usdmAddr = t1;
    }
    if (`${sym0}/${sym1}` === "USDC/USDm") {
      usdcUsdmAddr = addr;
      usdcAddr = t0;
      usdcDecimals = Number(await contractAt("ERC20", t0).decimals());
    }
  }

  // Fallback: if no USDC/USDm found, look for any USDC pool
  if (!usdcAddr) {
    for (const addr of fpmmAddresses) {
      const fpmm = contractAt("FPMM", addr);
      const [t0, t1] = await Promise.all([fpmm.token0(), fpmm.token1()]);
      const [sym0, sym1] = await Promise.all([
        contractAt("ERC20", t0).symbol(),
        contractAt("ERC20", t1).symbol(),
      ]);
      if (sym0 === "USDC" || sym1 === "USDC") {
        usdcAddr = sym0 === "USDC" ? t0 : t1;
        usdcDecimals = Number(await contractAt("ERC20", usdcAddr).decimals());
        usdcUsdmAddr = addr;
        break;
      }
    }
  }

  if (!usdcAddr) throw new Error("No USDC pool found in deployed FPMMs");

  // ── Virtual pool addresses (Celo-only) ────────────────────────────────
  const vpAddresses: string[] = celo && vpFactory
    ? await vpFactory.getAllPools()
    : [];

  // ── Trove data (Celo-only) ────────────────────────────────────────────
  let boldAddr = "";
  let collAddr = "";
  let collDecimals = 18;
  let gasTokenAddr = "";
  let MCR = 0n;
  let MIN_DEBT = 0n;
  let MIN_RATE = 0n;
  let GAS_COMPENSATION = 0n;

  if (celo && addressesRegistry && systemParams) {
    console.log("pre-test: fetching trove data...");
    boldAddr = await addressesRegistry.boldToken();
    collAddr = await addressesRegistry.collToken();
    collDecimals = Number(await contractAt("ERC20", collAddr).decimals());
    gasTokenAddr = await addressesRegistry.gasToken();
    MCR = await systemParams.MCR();
    MIN_DEBT = await systemParams.MIN_DEBT();
    MIN_RATE = await systemParams.MIN_ANNUAL_INTEREST_RATE();
    GAS_COMPENSATION = await systemParams.ETH_GAS_COMPENSATION();
  }

  // ── Accounts ────────────────────────────────────────────────────────
  const lpAddr = "0x" + "1".repeat(40);
  const traderAddr = "0x" + "2".repeat(40);

  const troveAccounts: string[] = [];
  for (let i = 0; i < 4; i++) {
    troveAccounts.push("0x" + "dead" + (i + 1).toString(16).padStart(36, "0"));
  }

  // ── Write fixture ───────────────────────────────────────────────────
  console.log("pre-test: writing fixture...");

  const systemPrice = originalPrice !== undefined && mockAggregatorDecimals !== undefined
    ? 10n ** (18n + BigInt(mockAggregatorDecimals)) / originalPrice
    : 0n;

  const fixture: TestFixture = {
    contracts: {
      fpmmFactory: fpmmFactory.target as string,
      router: router.target as string,
      sortedOracles: sortedOraclesAddr,
      breakerBox: breakerBoxAddr,
      reserveStrategy: reserveStrategy.target as string,
      ...(celo && vpFactory && { vpFactory: vpFactory.target as string }),
      ...(celo && biPoolManagerAddr && { biPoolManager: biPoolManagerAddr }),
      ...(celo && borrowerOps && { borrowerOps: borrowerOps.target as string }),
      ...(celo && troveManager && { troveManager: troveManager.target as string }),
      ...(celo && stabilityPool && { stabilityPool: stabilityPool.target as string }),
      ...(celo && hintHelpers && { hintHelpers: hintHelpers.target as string }),
      ...(celo && systemParams && { systemParams: systemParams.target as string }),
      ...(celo && addressesRegistry && { addressesRegistry: addressesRegistry.target as string }),
      ...(celo && mockAggregatorAddr && { mockAggregator: mockAggregatorAddr }),
      ...(celo && priceFeedAddr && { priceFeed: priceFeedAddr }),
      ...(celo && cdpStrategy && { cdpStrategy: cdpStrategy.target as string }),
    },
    fpmm: {
      allAddresses: fpmmAddresses,
      usdcAddr,
      usdcDecimals,
      protocolFeeRecipient,
      vpAddresses,
      ...(gbpmUsdmAddr && { gbpmUsdm: gbpmUsdmAddr }),
      ...(usdcUsdmAddr && { usdcUsdm: usdcUsdmAddr }),
      ...(gbpmAddr && { gbpmAddr }),
      ...(usdmAddr && { usdmAddr }),
    },
    ...(celo && boldAddr && {
      trove: {
        boldAddr,
        collAddr,
        collDecimals,
        gasTokenAddr,
        MCR: "0x" + MCR.toString(16),
        MIN_DEBT: "0x" + MIN_DEBT.toString(16),
        MIN_RATE: "0x" + MIN_RATE.toString(16),
        GAS_COMPENSATION: "0x" + GAS_COMPENSATION.toString(16),
        mockAggregatorDecimals: mockAggregatorDecimals!,
        originalPrice: "0x" + originalPrice!.toString(16),
        systemPrice: "0x" + systemPrice.toString(16),
        priceFeedRateFeedId: priceFeedRateFeedId!,
      },
    }),
    accounts: {
      lp: lpAddr,
      trader: traderAddr,
      troveAccounts,
    },
  };

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
