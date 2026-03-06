import { expect } from "chai";
import hre from "hardhat";
import { Contract, Signer } from "ethers";
import { setBalance, impersonateAccount, stopImpersonatingAccount, time } from "@nomicfoundation/hardhat-network-helpers";
import { contractAt, refreshSortedOracles, isCelo } from "../helpers/helpers";
import { loadFixture, hexToBigInt } from "../helpers/fixture";
import { setupTestAccounts } from "../helpers/setup";

describe("Troves", function() {
  before(async function() {
    if (!(await isCelo())) this.skip();
    await setupTestAccounts();
  });
  // Liquity contracts
  let borrowerOps: Contract;
  let troveManager: Contract;
  let stabilityPool: Contract;
  let hintHelpers: Contract;

  // Tokens
  let boldToken: Contract; // GBPm
  let collToken: Contract; // USDm
  let boldAddr: string;
  let collAddr: string;
  let collDecimals: bigint;

  // System params
  let MCR: bigint;
  let MIN_DEBT: bigint;
  let MIN_RATE: bigint;
  let GAS_COMPENSATION: bigint;

  // Mock oracle
  let mockAggregator: Contract;
  let mockAggregatorDecimals: bigint;
  let originalPrice: bigint; // raw Chainlink GBP/USD price (8 decimals)
  let systemPrice: bigint; // USD/GBP in 18 decimals (used by Liquity)
  let priceFeed: Contract; // FXPriceFeed (returns USD/GBP in 18 decimals)

  // Gas token (CELO on Celo)
  let gasTokenAddr: string;
  let gasToken: Contract;

  // Accounts
  const accounts: { addr: string; signer: Signer }[] = [];
  const troveIds: bigint[] = [];

  before(async function() {
    const f = loadFixture();

    borrowerOps = contractAt("BorrowerOperations", f.contracts.borrowerOps);
    troveManager = contractAt("TroveManager", f.contracts.troveManager);
    stabilityPool = contractAt("StabilityPool", f.contracts.stabilityPool);
    hintHelpers = contractAt("HintHelpers", f.contracts.hintHelpers);

    boldAddr = f.trove.boldAddr;
    collAddr = f.trove.collAddr;
    boldToken = contractAt("ERC20", boldAddr);
    collToken = contractAt("ERC20", collAddr);
    collDecimals = BigInt(f.trove.collDecimals);

    gasTokenAddr = f.trove.gasTokenAddr;
    gasToken = contractAt("ERC20", gasTokenAddr);

    MCR = hexToBigInt(f.trove.MCR);
    MIN_DEBT = hexToBigInt(f.trove.MIN_DEBT);
    MIN_RATE = hexToBigInt(f.trove.MIN_RATE);
    GAS_COMPENSATION = hexToBigInt(f.trove.GAS_COMPENSATION);

    mockAggregator = contractAt("MockChainlinkAggregator", f.contracts.mockAggregator);
    mockAggregatorDecimals = BigInt(f.trove.mockAggregatorDecimals);
    originalPrice = hexToBigInt(f.trove.originalPrice);
    systemPrice = hexToBigInt(f.trove.systemPrice);

    priceFeed = contractAt("FXPriceFeed", f.contracts.priceFeed);

    for (const addr of f.accounts.troveAccounts) {
      await impersonateAccount(addr);
      const signer = await hre.ethers.getSigner(addr);
      accounts.push({ addr, signer });
    }
  });

  after(async () => {
    for (const acc of accounts) {
      await stopImpersonatingAccount(acc.addr);
    }
  });

  // ── Helpers ──────────────────────────────────────────────────────────

  async function refreshOraclePrice(newChainlinkPrice?: bigint) {
    const aggOwner = await mockAggregator.owner();
    await impersonateAccount(aggOwner);
    await setBalance(aggOwner, 10n ** 18n);
    const ownerSigner = await hre.ethers.getSigner(aggOwner);
    const ts = await time.latest();
    await contractAt("MockChainlinkAggregator", await mockAggregator.getAddress(), ownerSigner)
      .report(newChainlinkPrice ?? originalPrice, ts);
    await stopImpersonatingAccount(aggOwner);

    const rateFeedId = await priceFeed.rateFeedID();
    const sortedOraclesAddr = loadFixture().contracts.sortedOracles;

    if (newChainlinkPrice && newChainlinkPrice !== originalPrice) {
      await updateSortedOracleValues(sortedOraclesAddr, rateFeedId, newChainlinkPrice);
    } else {
      await refreshSortedOracles(sortedOraclesAddr, rateFeedId);
    }
  }

  async function updateSortedOracleValues(
    sortedOraclesAddr: string,
    rateFeedId: string,
    newChainlinkPrice: bigint,
  ) {
    const sortedOracles = contractAt("SortedOracles", sortedOraclesAddr);
    const [oracles, values] = await sortedOracles.getRates(rateFeedId);

    const scaledValues: bigint[] = [];
    for (let i = 0; i < oracles.length; i++) {
      scaledValues.push((values[i] as bigint) * newChainlinkPrice / originalPrice);
    }

    for (let i = 0; i < oracles.length; i++) {
      const oracle = oracles[i] as string;
      const value = scaledValues[i];

      let lesserKey = hre.ethers.ZeroAddress;
      let greaterKey = hre.ethers.ZeroAddress;
      for (let j = 0; j < oracles.length; j++) {
        if (j === i) continue;
        if (scaledValues[j] < value) lesserKey = oracles[j] as string;
        if (scaledValues[j] >= value) greaterKey = oracles[j] as string;
      }

      await impersonateAccount(oracle);
      await setBalance(oracle, 10n ** 18n);
      const oracleSigner = await hre.ethers.getSigner(oracle);
      await contractAt("SortedOracles", sortedOraclesAddr, oracleSigner)
        .report(rateFeedId, value, lesserKey, greaterKey);
      await stopImpersonatingAccount(oracle);
    }

    await resetBreaker(rateFeedId);
  }

  async function resetBreaker(rateFeedId: string) {
    const breakerBoxAddr = loadFixture().contracts.breakerBox;
    const breakerBox = contractAt("BreakerBox", breakerBoxAddr);
    const bbOwner: string = await breakerBox.owner();
    await impersonateAccount(bbOwner);
    await setBalance(bbOwner, 10n ** 18n);
    const bbOwnerSigner = await hre.ethers.getSigner(bbOwner);
    await contractAt("BreakerBox", breakerBoxAddr, bbOwnerSigner)
      .setRateFeedTradingMode(rateFeedId, 0);
    await stopImpersonatingAccount(bbOwner);
  }

  function toSystemPrice(chainlinkPrice: bigint): bigint {
    return 10n ** (18n + mockAggregatorDecimals) / chainlinkPrice;
  }

  function calculateCollateral(debtAmount: bigint, sysPrice: bigint, ratio: bigint): bigint {
    return (debtAmount * ratio) / sysPrice;
  }

  let ownerIndexOffset = 0;

  async function openTrovesForAll(ratio: bigint) {
    const offset = ownerIndexOffset;
    ownerIndexOffset += accounts.length;

    for (let i = 0; i < accounts.length; i++) {
      const { addr, signer } = accounts[i];
      const ownerIndex = offset + i;
      const debtAmount = MIN_DEBT * 10n;
      const collAmount = calculateCollateral(debtAmount, systemPrice, ratio);
      const rate = MIN_RATE + BigInt(i) * 10n ** 15n;

      await collToken.connect(signer).approve(borrowerOps.target, collAmount + GAS_COMPENSATION);
      await gasToken.connect(signer).approve(borrowerOps.target, GAS_COMPENSATION);
      const upfrontFee = await hintHelpers.predictOpenTroveUpfrontFee(0, debtAmount, rate);

      const troveId = BigInt(hre.ethers.keccak256(
        hre.ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "address", "uint256"],
          [addr, addr, ownerIndex],
        )
      ));

      await borrowerOps.connect(signer).openTrove(
        addr, ownerIndex, collAmount, debtAmount, 0, 0,
        rate, upfrontFee * 2n,
        hre.ethers.ZeroAddress, hre.ethers.ZeroAddress, hre.ethers.ZeroAddress,
      );

      troveIds[i] = troveId;
    }
  }

  // ── Tests ────────────────────────────────────────────────────────────

  describe("Opening troves", function() {
    it("Should open troves for multiple accounts", async function() {
      this.timeout(30_000);
      await openTrovesForAll(2n * 10n ** 18n);

      for (let i = 0; i < accounts.length; i++) {
        const status = await troveManager.getTroveStatus(troveIds[i]);
        expect(status).to.equal(1n); // active
      }
    });
  });

  describe("Stability pool", function() {
    before(async function() {
      this.timeout(30_000);
      await openTrovesForAll(2n * 10n ** 18n);
    });

    it("Should provide to stability pool", async function() {
      for (const idx of [0, 1]) {
        const { signer, addr } = accounts[idx];
        const boldBal = await boldToken.balanceOf(addr);
        const provideAmount = boldBal / 2n;
        await boldToken.connect(signer).approve(stabilityPool.target, provideAmount);
        await stabilityPool.connect(signer).provideToSP(provideAmount, false);
        const deposit = await stabilityPool.getCompoundedBoldDeposit(addr);
        expect(deposit).to.be.greaterThan(0n);
      }

      const totalDeposits = await stabilityPool.getTotalBoldDeposits();
      expect(totalDeposits).to.be.greaterThan(0n);
    });
  });

  describe("Trove management", function() {
    before(async function() {
      this.timeout(30_000);
      await openTrovesForAll(2n * 10n ** 18n);
    });

    it("Should adjust interest rate", async function() {
      const { signer } = accounts[0];
      const troveId = troveIds[0];
      const newRate = MIN_RATE * 5n;

      const upfrontFee = await hintHelpers.predictAdjustInterestRateUpfrontFee(0, troveId, newRate);
      await borrowerOps.connect(signer).adjustTroveInterestRate(
        troveId, newRate, 0, 0, upfrontFee * 2n
      );

      const rate = await troveManager.getTroveAnnualInterestRate(troveId);
      expect(rate).to.equal(newRate);
    });

    it("Should add collateral", async function() {
      const { signer } = accounts[1];
      const troveId = troveIds[1];
      const addAmount = 1_000n * 10n ** collDecimals;

      const dataBefore = await troveManager.getLatestTroveData(troveId);
      await collToken.connect(signer).approve(borrowerOps.target, addAmount);
      await borrowerOps.connect(signer).addColl(troveId, addAmount);
      const dataAfter = await troveManager.getLatestTroveData(troveId);

      expect(dataAfter.entireColl).to.be.greaterThan(dataBefore.entireColl);
    });

    it("Should withdraw collateral", async function() {
      const { signer } = accounts[1];
      const troveId = troveIds[1];
      const withdrawAmount = 100n * 10n ** collDecimals;

      const dataBefore = await troveManager.getLatestTroveData(troveId);
      await borrowerOps.connect(signer).withdrawColl(troveId, withdrawAmount);
      const dataAfter = await troveManager.getLatestTroveData(troveId);

      expect(dataAfter.entireColl).to.be.lessThan(dataBefore.entireColl);
    });

    it("Should repay debt", async function() {
      const { signer } = accounts[2];
      const troveId = troveIds[2];
      const repayAmount = MIN_DEBT;

      const dataBefore = await troveManager.getLatestTroveData(troveId);
      await boldToken.connect(signer).approve(borrowerOps.target, repayAmount);
      await borrowerOps.connect(signer).repayBold(troveId, repayAmount);
      const dataAfter = await troveManager.getLatestTroveData(troveId);

      expect(dataAfter.entireDebt).to.be.lessThan(dataBefore.entireDebt);
    });

    it("Should borrow more", async function() {
      const { signer } = accounts[2];
      const troveId = troveIds[2];
      const borrowAmount = MIN_DEBT / 2n;

      const dataBefore = await troveManager.getLatestTroveData(troveId);
      const upfrontFee = await hintHelpers.predictAdjustTroveUpfrontFee(0, troveId, borrowAmount);
      await borrowerOps.connect(signer).withdrawBold(troveId, borrowAmount, upfrontFee * 2n);
      const dataAfter = await troveManager.getLatestTroveData(troveId);

      expect(dataAfter.entireDebt).to.be.greaterThan(dataBefore.entireDebt);
    });

    it("Should accrue interest over time", async function() {
      const troveId = troveIds[0];
      const dataBefore = await troveManager.getLatestTroveData(troveId);

      await time.increase(30 * 24 * 3600);
      await refreshOraclePrice(originalPrice);

      const dataAfter = await troveManager.getLatestTroveData(troveId);
      expect(dataAfter.entireDebt).to.be.greaterThan(dataBefore.entireDebt);
    });
  });

  describe("Liquidations", function() {
    before(async function() {
      this.timeout(30_000);
      await openTrovesForAll(16n * 10n ** 17n);

      for (const idx of [0, 1]) {
        const { signer, addr } = accounts[idx];
        const boldBal = await boldToken.balanceOf(addr);
        await boldToken.connect(signer).approve(stabilityPool.target, boldBal);
        await stabilityPool.connect(signer).provideToSP(boldBal, false);
      }
    });

    it("Should make troves liquidatable by increasing GBP/USD", async function() {
      this.timeout(30_000);

      const icrBefore = await troveManager.getCurrentICR(troveIds[2], systemPrice);
      expect(icrBefore).to.be.greaterThan(MCR);

      // Increase GBP/USD by 60% → USD/GBP drops → ICR drops
      const raisedPrice = originalPrice * 160n / 100n;
      await refreshOraclePrice(raisedPrice);

      const icrAfter = await troveManager.getCurrentICR(troveIds[2], toSystemPrice(raisedPrice));
      expect(icrAfter).to.be.lessThan(MCR);
    });

    it("Should liquidate via stability pool", async function() {
      this.timeout(30_000);

      const spBoldBefore = await stabilityPool.getTotalBoldDeposits();

      const raisedPrice = originalPrice * 160n / 100n;
      await refreshOraclePrice(raisedPrice);

      const rateFeedId = await priceFeed.rateFeedID();
      await resetBreaker(rateFeedId);

      await troveManager.connect(accounts[3].signer).batchLiquidateTroves([troveIds[2]]);

      const status = await troveManager.getTroveStatus(troveIds[2]);
      expect(status).to.equal(3n); // closedByLiquidation

      const spBoldAfter = await stabilityPool.getTotalBoldDeposits();
      expect(spBoldAfter).to.be.lessThan(spBoldBefore);

      const collGain0 = await stabilityPool.getDepositorCollGain(accounts[0].addr);
      const collGain1 = await stabilityPool.getDepositorCollGain(accounts[1].addr);
      expect(collGain0 + collGain1).to.be.greaterThan(0n);
    });

    it("Should batch liquidate multiple troves", async function() {
      this.timeout(30_000);

      const raisedPrice = originalPrice * 200n / 100n;
      await refreshOraclePrice(raisedPrice);
      const price = toSystemPrice(raisedPrice);

      const liquidatable: bigint[] = [];
      for (let i = 0; i < troveIds.length; i++) {
        const status = await troveManager.getTroveStatus(troveIds[i]);
        if (status !== 1n) continue;
        const icr = await troveManager.getCurrentICR(troveIds[i], price);
        if (icr < MCR) liquidatable.push(troveIds[i]);
      }

      if (liquidatable.length === 0) return;

      const rateFeedId = await priceFeed.rateFeedID();
      await resetBreaker(rateFeedId);

      await troveManager.connect(accounts[0].signer).batchLiquidateTroves(liquidatable);

      let liquidated = 0;
      for (const id of liquidatable) {
        const status = await troveManager.getTroveStatus(id);
        if (status === 3n || status === 4n) liquidated++;
      }
      expect(liquidated).to.be.greaterThan(0);
    });
  });
});
