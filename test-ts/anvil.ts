import hre from "hardhat";

export async function snapshot(): Promise<string> {
  return hre.ethers.provider.send("evm_snapshot", []);
}

export async function revert(id: string): Promise<void> {
  await hre.ethers.provider.send("evm_revert", [id]);
}

export async function increaseTime(seconds: number): Promise<void> {
  await hre.ethers.provider.send("evm_increaseTime", [seconds]);
  await hre.ethers.provider.send("evm_mine", []);
}

export async function mine(blocks: number = 1): Promise<void> {
  for (let i = 0; i < blocks; i++) {
    await hre.ethers.provider.send("evm_mine", []);
  }
}

export async function getBlockTimestamp(): Promise<number> {
  const block = await hre.ethers.provider.getBlock("latest");
  return block!.timestamp;
}

export async function setBalance(address: string, wei: bigint): Promise<void> {
  await hre.ethers.provider.send("anvil_setBalance", [
    address,
    "0x" + wei.toString(16),
  ]);
}

/**
 * Set an ERC20 balance by writing directly to storage.
 * @param balanceSlot - The storage slot index for the balanceOf mapping (e.g. 0 for CELO).
 */
export async function setERC20Balance(
  token: string,
  account: string,
  amount: bigint,
  balanceSlot: number = 0,
): Promise<void> {
  const slot = hre.ethers.keccak256(
    hre.ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [account, balanceSlot],
    )
  );
  const value = "0x" + amount.toString(16).padStart(64, "0");
  await hre.ethers.provider.send("anvil_setStorageAt", [token, slot, value]);
}

export async function impersonate(address: string): Promise<void> {
  await hre.ethers.provider.send("anvil_impersonateAccount", [address]);
}

export async function stopImpersonating(address: string): Promise<void> {
  await hre.ethers.provider.send("anvil_stopImpersonatingAccount", [address]);
}


