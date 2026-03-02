import { expect } from "chai";
import hre from "hardhat";
import { Contract } from "ethers";
import { getForgeArtifact } from "../hardhat.config";
import { getDeployedContract, getRegistryAddress } from "./treb";

function contractAt(name: string, address: string): Contract {
  const { abi } = getForgeArtifact(name);
  return new Contract(address, abi, hre.ethers.provider);
}

async function tokenSymbol(address: string): Promise<string> {
  return contractAt("ERC20", address).symbol();
}

describe("FPMMs", function() {
  let fpmmFactory: Contract;
  let fpmmAddresses: string[];

  before(async () => {
    fpmmFactory = await getDeployedContract("FPMMFactory");
    fpmmAddresses = await fpmmFactory.deployedFPMMAddresses();
  });

  it("Should have deployed FPMMs", async () => {
    expect(fpmmAddresses.length).to.be.greaterThan(0);
  });

  it("Should have valid token pairs and reserves", async () => {
    for (const addr of fpmmAddresses) {
      const fpmm = contractAt("FPMM", addr);
      const [t0, t1, r0, r1] = await Promise.all([
        fpmm.token0(),
        fpmm.token1(),
        fpmm.reserve0(),
        fpmm.reserve1(),
      ]);
      const [sym0, sym1] = await Promise.all([tokenSymbol(t0), tokenSymbol(t1)]);
      console.log(`    ${addr}: ${sym0}/${sym1} (reserves: ${r0}, ${r1})`);

      expect(t0).to.not.equal(t1);
      expect(r0).to.be.greaterThan(0n);
      expect(r1).to.be.greaterThan(0n);
    }
  });

  it("Should have oracle adapters and rate feeds configured", async () => {
    for (const addr of fpmmAddresses) {
      const fpmm = contractAt("FPMM", addr);
      const [oracleAdapter, rateFeedId] = await Promise.all([
        fpmm.oracleAdapter(),
        fpmm.referenceRateFeedID(),
      ]);
      expect(oracleAdapter).to.not.equal(hre.ethers.ZeroAddress);
      expect(rateFeedId).to.not.equal(hre.ethers.ZeroAddress);
    }
  });

  it("Should have fees configured", async () => {
    for (const addr of fpmmAddresses) {
      const fpmm = contractAt("FPMM", addr);
      const [protocolFee, lpFee] = await Promise.all([
        fpmm.protocolFee(),
        fpmm.lpFee(),
      ]);
      console.log(`    ${addr}: protocolFee=${protocolFee}, lpFee=${lpFee}`);
      expect(protocolFee).to.be.greaterThan(0n);
      expect(lpFee).to.be.greaterThan(0n);
    }
  });
});

describe("Virtual Pools", function() {
  let vpFactory: Contract;
  let vpAddresses: string[];

  before(async () => {
    vpFactory = await getDeployedContract("VirtualPoolFactory");
    vpAddresses = await vpFactory.getAllPools();
  });

  it("Should have deployed Virtual Pools", async () => {
    expect(vpAddresses.length).to.be.greaterThan(0);
  });

  it("Should have valid token pairs", async () => {
    for (const addr of vpAddresses) {
      const vp = contractAt("VirtualPool", addr);
      const [t0, t1] = await Promise.all([vp.token0(), vp.token1()]);
      const [sym0, sym1] = await Promise.all([tokenSymbol(t0), tokenSymbol(t1)]);
      console.log(`    ${addr}: ${sym0}/${sym1}`);
      expect(t0).to.not.equal(t1);
    }
  });
});

describe("Liquity (GBPm)", function() {
  it("Should have core Liquity contracts deployed", async () => {
    const contracts = [
      "BorrowerOperations",
      "TroveManager",
      "StabilityPool",
      "ActivePool",
      "CollateralRegistry",
      "HintHelpers",
      "SortedTroves",
      "SystemParams",
      "FXPriceFeed",
      "TroveNFT",
    ];

    for (const name of contracts) {
      const contract = await getDeployedContract(name);
      expect(contract.target).to.not.equal(hre.ethers.ZeroAddress);
      console.log(`    ${name}: ${contract.target}`);
    }
  });

  it("Should have system params configured", async () => {
    const systemParams = await getDeployedContract("SystemParams");
    const [ccr, mcr, minDebt, minRate] = await Promise.all([
      systemParams.CCR(),
      systemParams.MCR(),
      systemParams.MIN_DEBT(),
      systemParams.MIN_ANNUAL_INTEREST_RATE(),
    ]);
    console.log(`    CCR: ${ccr}, MCR: ${mcr}, MIN_DEBT: ${minDebt}, MIN_RATE: ${minRate}`);
    expect(ccr).to.be.greaterThan(0n);
    expect(mcr).to.be.greaterThan(0n);
    expect(minDebt).to.be.greaterThan(0n);
    expect(minRate).to.be.greaterThan(0n);
  });

  it("Should have a functioning price feed", async () => {
    // FXPriceFeed proxy has a non-standard registry key pattern
    // ("TransparentUpgradeableProxy:FXPriceFeedProxy:GBPm")
    // so we use the registry lookup helper to get the proxy address directly
    const proxyAddr = await getRegistryAddress("TransparentUpgradeableProxy:FXPriceFeedProxy:GBPm");
    const priceFeed = contractAt("FXPriceFeed", proxyAddr);
    const rateFeedId = await priceFeed.rateFeedID();
    const oracleAdapter = await priceFeed.oracleAdapter();
    console.log(`    proxy: ${proxyAddr}`);
    console.log(`    rateFeedID: ${rateFeedId}`);
    console.log(`    oracleAdapter: ${oracleAdapter}`);
    expect(rateFeedId).to.not.equal(hre.ethers.ZeroAddress);
    expect(oracleAdapter).to.not.equal(hre.ethers.ZeroAddress);
  });
});

describe("Infrastructure", function() {
  it("Should have OracleAdapter deployed", async () => {
    const oracleAdapter = await getDeployedContract("OracleAdapter");
    expect(oracleAdapter.target).to.not.equal(hre.ethers.ZeroAddress);
  });

  it("Should have CDPLiquidityStrategy deployed", async () => {
    const strategy = await getDeployedContract("CDPLiquidityStrategy");
    expect(strategy.target).to.not.equal(hre.ethers.ZeroAddress);
  });

  it("Should have ReserveLiquidityStrategy deployed", async () => {
    const strategy = await getDeployedContract("ReserveLiquidityStrategy");
    expect(strategy.target).to.not.equal(hre.ethers.ZeroAddress);
  });

  it("Should have Router deployed", async () => {
    const router = await getDeployedContract("Router");
    expect(router.target).to.not.equal(hre.ethers.ZeroAddress);
  });

  it("Should have FactoryRegistry with both factories", async () => {
    const factoryRegistry = await getDeployedContract("FactoryRegistry");
    const fpmmFactory = await getDeployedContract("FPMMFactory");
    const vpFactory = await getDeployedContract("VirtualPoolFactory");

    const isFPMMRegistered = await factoryRegistry.isPoolFactoryApproved(fpmmFactory.target);
    const isVPRegistered = await factoryRegistry.isPoolFactoryApproved(vpFactory.target);

    expect(isFPMMRegistered).to.be.true;
    expect(isVPRegistered).to.be.true;
  });
});
