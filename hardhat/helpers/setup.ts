import hre from "hardhat";
import { Contract } from "ethers";
import { setBalance, impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-network-helpers";
import {
  contractAt,
  mintStableToken,
  refreshAllBiPoolOracles,
  refreshSortedOracles,
  isCelo,
} from "./helpers";
import { loadFixture } from "./fixture";

/**
 * Fund test accounts and refresh oracles.
 * Call this in a `before` hook in any test suite that needs funded accounts.
 * Transactions are applied to the in-process Hardhat fork and take effect immediately.
 */
export async function setupTestAccounts(): Promise<void> {
  const f = loadFixture();
  const celo = await isCelo();

  const { lp: lpAddr, trader: traderAddr, troveAccounts } = f.accounts;
  const { usdcAddr, usdcDecimals, usdmAddr, gbpmAddr } = f.fpmm;
  const { sortedOracles: sortedOraclesAddr } = f.contracts;

  // ── ETH balances ────────────────────────────────────────────────────
  for (const addr of [lpAddr, traderAddr, ...troveAccounts]) {
    await setBalance(addr, 10n ** 18n);
  }

  // ── Stable token balances ────────────────────────────────────────────
  if (usdmAddr) {
    await mintStableToken(usdmAddr, lpAddr, 100_000n * 10n ** 18n);
    await mintStableToken(usdmAddr, traderAddr, 100_000n * 10n ** 18n);
  }
  if (gbpmAddr) {
    await mintStableToken(gbpmAddr, lpAddr, 100_000n * 10n ** 18n);
    await mintStableToken(gbpmAddr, traderAddr, 100_000n * 10n ** 18n);
  }

  // ── USDC balance (via Circle's FiatToken masterMinter) ─────────────
  const usdcAmount = 100_000n * 10n ** BigInt(usdcDecimals);
  await mintFiatToken(usdcAddr, lpAddr, usdcAmount);
  await mintFiatToken(usdcAddr, traderAddr, usdcAmount);

  if (!celo) return;

  // ── Celo-only: collateral + gas token for trove accounts ────────────
  if (f.trove) {
    const { collAddr, collDecimals, gasTokenAddr } = f.trove;
    const collAmount = 100_000n * 10n ** BigInt(collDecimals);
    for (const addr of troveAccounts) {
      await mintStableToken(collAddr, addr, collAmount);
      await mintStableToken(gasTokenAddr, addr, 100n * 10n ** 18n);
    }
  }

  // ── Celo-only: refresh BiPool oracles ───────────────────────────────
  const biPoolManagerAddr = f.contracts.biPoolManager;
  if (biPoolManagerAddr) {
    await refreshAllBiPoolOracles(biPoolManagerAddr, sortedOraclesAddr);
  }

  // ── Celo-only: report mock aggregator price ──────────────────────────
  const mockAggregatorAddr = f.contracts.mockAggregator;
  if (mockAggregatorAddr && f.trove) {
    const originalPrice = BigInt(f.trove.originalPrice);
    const mockAggregator = contractAt("MockChainlinkAggregator", mockAggregatorAddr);
    const aggOwner: string = await mockAggregator.owner();
    await impersonateAccount(aggOwner);
    await setBalance(aggOwner, 10n ** 18n);
    const ownerSigner = await hre.ethers.getSigner(aggOwner);
    const block = await hre.ethers.provider.getBlock("latest");
    await contractAt("MockChainlinkAggregator", mockAggregatorAddr, ownerSigner)
      .report(originalPrice, block!.timestamp);
    await stopImpersonatingAccount(aggOwner);

    if (f.trove.priceFeedRateFeedId) {
      await refreshSortedOracles(sortedOraclesAddr, f.trove.priceFeedRateFeedId);
    }
  }
}

/**
 * Mint a Circle FiatToken (e.g. USDC) by impersonating the masterMinter.
 */
async function mintFiatToken(tokenAddr: string, to: string, amount: bigint): Promise<void> {
  const fiatToken = new Contract(
    tokenAddr,
    [
      "function masterMinter() view returns (address)",
      "function configureMinter(address minter, uint256 allowance) returns (bool)",
      "function mint(address to, uint256 amount) returns (bool)",
    ],
    hre.ethers.provider,
  );

  const masterMinter: string = await fiatToken.masterMinter();
  await impersonateAccount(masterMinter);
  await setBalance(masterMinter, 10n ** 18n);
  const mmSigner = await hre.ethers.getSigner(masterMinter);

  await fiatToken.connect(mmSigner).configureMinter(masterMinter, amount);
  await fiatToken.connect(mmSigner).mint(to, amount);

  await stopImpersonatingAccount(masterMinter);
}
