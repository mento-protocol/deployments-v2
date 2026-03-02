import fs from "fs";
import path from "path";

const FIXTURE_PATH = path.resolve(__dirname, "../.treb/priv/test-fixture.json");

export interface TestFixture {
  snapshotId: string;
  contracts: {
    fpmmFactory: string;
    router: string;
    vpFactory: string;
    biPoolManager: string;
    sortedOracles: string;
    borrowerOps: string;
    troveManager: string;
    stabilityPool: string;
    hintHelpers: string;
    systemParams: string;
    addressesRegistry: string;
    mockAggregator: string;
    priceFeed: string;
    breakerBox: string;
    reserveStrategy: string;
    cdpStrategy: string;
  };
  fpmm: {
    gbpmUsdm: string;
    usdcUsdm: string;
    gbpmAddr: string;
    usdmAddr: string;
    usdcAddr: string;
    usdcDecimals: number;
    protocolFeeRecipient: string;
    vpAddresses: string[];
  };
  trove: {
    boldAddr: string;
    collAddr: string;
    collDecimals: number;
    gasTokenAddr: string;
    MCR: string;
    MIN_DEBT: string;
    MIN_RATE: string;
    GAS_COMPENSATION: string;
    mockAggregatorDecimals: number;
    originalPrice: string;
    systemPrice: string;
    priceFeedRateFeedId: string;
  };
  accounts: {
    lp: string;
    trader: string;
    troveAccounts: string[];
  };
}

let cached: TestFixture | undefined;

export function loadFixture(): TestFixture {
  if (cached) return cached;
  if (!fs.existsSync(FIXTURE_PATH)) {
    throw new Error(
      `Test fixture not found at ${FIXTURE_PATH}. Run 'hardhat run test-ts/pre-test.ts' first.`
    );
  }
  cached = JSON.parse(fs.readFileSync(FIXTURE_PATH, "utf8")) as TestFixture;
  return cached;
}

export function hexToBigInt(s: string): bigint {
  return BigInt(s);
}
