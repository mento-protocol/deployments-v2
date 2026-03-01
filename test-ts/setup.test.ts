import { expect } from "chai";
import hre from "hardhat";
import { ContractFactory } from "ethers";
import { getForgeArtifact } from "../hardhat.config";

describe("Setup", function() {
  it("Should load artifacts", async () => {
    const { abi, bytecode } = getForgeArtifact("FPMM");
    const [signer] = await hre.ethers.getSigners();
    const FPMM = new ContractFactory(abi, bytecode, signer);
    console.log("FPMM factory loaded, deploy tx data length:", FPMM.bytecode.length);
    expect(abi.length).to.be.greaterThan(0);
  });
})
