import fs from "fs";
import path from "path";
import hre from "hardhat";
import { Contract, Signer } from "ethers";
import { getForgeArtifact } from "../hardhat.config";
import { impersonate, stopImpersonating, setBalance } from "./anvil";

/** ERC1967 implementation slot */
const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

export function contractAt(name: string, address: string, signer?: Signer): Contract {
  const { abi } = getForgeArtifact(name);
  return new Contract(address, abi, signer ?? hre.ethers.provider);
}

export async function tokenSymbol(address: string): Promise<string> {
  return contractAt("ERC20", address).symbol();
}

async function getImplementation(proxyAddr: string): Promise<string> {
  const raw = await hre.ethers.provider.getStorage(proxyAddr, IMPL_SLOT);
  return "0x" + raw.slice(26);
}

function getRegisteredImpls(prefix: string): Set<string> {
  const registryPath = path.resolve(__dirname, "../.treb/registry.json");
  const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
  const addrs = new Set<string>();
  for (const chains of Object.values<any>(registry)) {
    for (const ns of Object.values<any>(chains)) {
      for (const [key, addr] of Object.entries<string>(ns)) {
        if (key === prefix || key.startsWith(prefix + ":")) {
          addrs.add(addr.toLowerCase());
        }
      }
    }
  }
  return addrs;
}

/**
 * Mint a StableToken (V2 or V3) to a recipient.
 */
export async function mintStableToken(
  tokenAddr: string,
  to: string,
  amount: bigint,
): Promise<void> {
  const impl = (await getImplementation(tokenAddr)).toLowerCase();
  const v3Impls = getRegisteredImpls("StableTokenV3");

  if (v3Impls.has(impl)) {
    await mintStableTokenV3(tokenAddr, to, amount);
  } else {
    await mintStableTokenV2(tokenAddr, to, amount);
  }
}

async function mintStableTokenV2(
  tokenAddr: string,
  to: string,
  amount: bigint,
): Promise<void> {
  const token = contractAt("StableTokenV2", tokenAddr);
  const broker: string = await token.broker();

  await impersonate(broker);
  await setBalance(broker, 10n ** 18n);
  const brokerSigner = await hre.ethers.getSigner(broker);
  await contractAt("StableTokenV2", tokenAddr, brokerSigner).mint(to, amount);
  await stopImpersonating(broker);
}

async function mintStableTokenV3(
  tokenAddr: string,
  to: string,
  amount: bigint,
): Promise<void> {
  const token = contractAt("StableTokenV3", tokenAddr);
  const owner: string = await token.owner();

  await impersonate(owner);
  await setBalance(owner, 10n ** 18n);
  const ownerSigner = await hre.ethers.getSigner(owner);
  const tokenAsOwner = contractAt("StableTokenV3", tokenAddr, ownerSigner);

  const wasMinter = await token.isMinter(owner);
  if (!wasMinter) {
    await tokenAsOwner.setMinter(owner, true);
  }
  await tokenAsOwner.mint(to, amount);
  if (!wasMinter) {
    await tokenAsOwner.setMinter(owner, false);
  }

  await stopImpersonating(owner);
}

/**
 * Refresh all oracle reports for a SortedOracles rateFeedID.
 */
export async function refreshSortedOracles(
  sortedOraclesAddr: string,
  rateFeedId: string,
): Promise<void> {
  const sortedOracles = contractAt("SortedOracles", sortedOraclesAddr);
  const [oracles, values] = await sortedOracles.getRates(rateFeedId);

  for (let i = 0; i < oracles.length; i++) {
    const oracle = oracles[i] as string;
    const value = values[i] as bigint;

    let lesserKey = hre.ethers.ZeroAddress;
    let greaterKey = hre.ethers.ZeroAddress;
    for (let j = 0; j < oracles.length; j++) {
      if (j === i) continue;
      const v = values[j] as bigint;
      if (v < value) lesserKey = oracles[j] as string;
      if (v >= value) greaterKey = oracles[j] as string;
    }

    await impersonate(oracle);
    await setBalance(oracle, 10n ** 18n);
    const oracleSigner = await hre.ethers.getSigner(oracle);
    await contractAt("SortedOracles", sortedOraclesAddr, oracleSigner)
      .report(rateFeedId, value, lesserKey, greaterKey);
    await stopImpersonating(oracle);
  }
}

/**
 * Refresh oracles for all exchanges in a BiPoolManager.
 */
export async function refreshAllBiPoolOracles(
  biPoolManagerAddr: string,
  sortedOraclesAddr: string,
): Promise<void> {
  const biPoolManager = contractAt("BiPoolManager", biPoolManagerAddr);
  const exchangeIds: string[] = await biPoolManager.getExchangeIds();
  const seen = new Set<string>();

  for (const eid of exchangeIds) {
    const exchange = await biPoolManager.getPoolExchange(eid);
    const rateFeedId = exchange.config.referenceRateFeedID as string;
    if (seen.has(rateFeedId.toLowerCase())) continue;
    seen.add(rateFeedId.toLowerCase());
    await refreshSortedOracles(sortedOraclesAddr, rateFeedId);
  }
}

/**
 * Transfer tokens from a whale to a recipient.
 */
export async function drainWhale(
  tokenAddr: string,
  whale: string,
  to: string,
  amount: bigint,
): Promise<void> {
  await impersonate(whale);
  await setBalance(whale, 10n ** 18n);
  const whaleSigner = await hre.ethers.getSigner(whale);
  await contractAt("ERC20", tokenAddr, whaleSigner).transfer(to, amount);
  await stopImpersonating(whale);
}
