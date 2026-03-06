import fs from "fs";
import path from "path";

export const FIXTURE_PATH = path.resolve(__dirname, "../fixture.json");

export interface TestFixture {
  contracts: {
    fpmmFactory: string;
    router: string;
    sortedOracles: string;
    breakerBox: string;
    reserveStrategy: string;
    // Celo-only:
    vpFactory?: string;
    biPoolManager?: string;
    borrowerOps?: string;
    troveManager?: string;
    stabilityPool?: string;
    hintHelpers?: string;
    systemParams?: string;
    addressesRegistry?: string;
    mockAggregator?: string;
    priceFeed?: string;
    cdpStrategy?: string;
  };
  fpmm: {
    allAddresses: string[];
    usdcAddr: string;
    usdcDecimals: number;
    protocolFeeRecipient: string;
    vpAddresses: string[];
    // Celo-only:
    gbpmUsdm?: string;
    usdcUsdm?: string;
    gbpmAddr?: string;
    usdmAddr?: string;
  };
  // Celo-only:
  trove?: {
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
      `Test fixture not found at ${FIXTURE_PATH}. Run 'pnpm pre-test' first.`
    );
  }
  cached = JSON.parse(fs.readFileSync(FIXTURE_PATH, "utf8")) as TestFixture;
  return cached;
}

export function hexToBigInt(s: string): bigint {
  return BigInt(s);
}
