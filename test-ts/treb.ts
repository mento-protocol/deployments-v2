import fs from "fs";
import path from "path";
import hre from "hardhat";
import { Contract, Wallet, InterfaceAbi } from "ethers";
import { getForgeArtifact, trebRuntime } from "../hardhat.config";

type Registry = Record<string, Record<string, Record<string, string>>>;

function loadRegistry(): Registry {
  const registryPath = path.resolve(__dirname, "../.treb/registry.json");
  return JSON.parse(fs.readFileSync(registryPath, "utf8"));
}

async function getChainId(): Promise<string> {
  const network = await hre.ethers.provider.getNetwork();
  return network.chainId.toString();
}

function getNamespaceRegistry(
  registry: Registry,
  chainId: string,
  namespace: string
): Record<string, string> {
  const chainRegistry = registry[chainId];
  if (!chainRegistry) {
    throw new Error(`No registry entries for chain ${chainId}`);
  }
  const nsRegistry = chainRegistry[namespace];
  if (!nsRegistry) {
    throw new Error(
      `No registry entries for namespace "${namespace}" on chain ${chainId}. ` +
        `Available: ${Object.keys(chainRegistry).join(", ")}`
    );
  }
  return nsRegistry;
}

/**
 * Find a registry entry by name. Handles versioned names like "Broker:v2.6.5"
 * by matching the prefix when an exact match isn't found.
 */
function findEntry(
  nsRegistry: Record<string, string>,
  name: string
): { key: string; address: string } | undefined {
  // Exact match first
  if (nsRegistry[name]) {
    return { key: name, address: nsRegistry[name] };
  }
  // Try prefix match for versioned entries (e.g. "Broker" matches "Broker:v2.6.5")
  const candidates = Object.entries(nsRegistry).filter(
    ([k]) => k === name || k.startsWith(name + ":")
  );
  if (candidates.length === 1) {
    return { key: candidates[0][0], address: candidates[0][1] };
  }
  if (candidates.length > 1) {
    throw new Error(
      `Ambiguous contract name "${name}", matches: ${candidates.map(([k]) => k).join(", ")}`
    );
  }
  return undefined;
}

/**
 * Look up a raw address from the treb registry by exact key.
 */
export async function getRegistryAddress(
  key: string,
  opts: { namespace?: string } = {}
): Promise<string> {
  const registry = loadRegistry();
  const chainId = await getChainId();
  const namespace = opts.namespace ?? trebRuntime.namespace;
  const nsRegistry = getNamespaceRegistry(registry, chainId, namespace);
  const address = nsRegistry[key];
  if (!address) {
    throw new Error(
      `Key "${key}" not found in registry (chain=${chainId}, namespace="${namespace}")`
    );
  }
  return address;
}

/**
 * Look up a deployed contract from the treb registry.
 *
 * For proxied contracts (where "Proxy:<name>" exists in the registry),
 * the returned contract is at the proxy address with the combined ABI
 * of the proxy and implementation contracts.
 *
 * @param name - Contract name (e.g. "Broker", "BiPoolManager", "Proxy:Broker")
 * @param opts.namespace - Override the active namespace
 * @param opts.proxyArtifact - Override the proxy artifact name (default: auto-detected from "Proxy" artifact)
 * @param opts.implArtifact - Override the implementation artifact name (default: inferred from registry name)
 */
export async function getDeployedContract(
  name: string,
  opts: { namespace?: string; proxyArtifact?: string; implArtifact?: string } = {}
): Promise<Contract> {
  const registry = loadRegistry();
  const chainId = await getChainId();
  const namespace = opts.namespace ?? trebRuntime.namespace;
  const nsRegistry = getNamespaceRegistry(registry, chainId, namespace);

  // Check for proxy entries matching patterns like:
  //   "Proxy:<name>", "TransparentUpgradeableProxy:<name>",
  //   "TransparentUpgradeableProxy:<name>:<suffix>"
  const proxyPrefixes = ["Proxy", "TransparentUpgradeableProxy"];
  let proxyAddress: string | undefined;
  let proxyArtifactDefault: string | undefined;
  for (const prefix of proxyPrefixes) {
    // Try exact match first, then prefix match for suffixed entries
    const exactKey = `${prefix}:${name}`;
    if (nsRegistry[exactKey]) {
      proxyAddress = nsRegistry[exactKey];
      proxyArtifactDefault = prefix;
      break;
    }
    // Look for entries like "TransparentUpgradeableProxy:FXPriceFeedProxy:GBPm"
    const proxyPrefix = `${prefix}:${name}:`;
    const match = Object.entries(nsRegistry).find(([k]) => k.startsWith(proxyPrefix));
    if (match) {
      proxyAddress = match[1];
      proxyArtifactDefault = prefix;
      break;
    }
  }

  if (proxyAddress) {
    // It's a proxied contract: use proxy address, combined ABI
    const implEntry = findEntry(nsRegistry, name);
    if (!implEntry) {
      throw new Error(
        `Found proxy for "${name}" but no implementation entry in registry`
      );
    }

    const implArtifactName = opts.implArtifact ?? name;
    const proxyArtifactName = opts.proxyArtifact ?? proxyArtifactDefault!;

    const implAbi = getForgeArtifact(implArtifactName).abi;
    const proxyAbi = getForgeArtifact(proxyArtifactName).abi;
    const combinedAbi = mergeAbis(proxyAbi, implAbi);

    const [signer] = await hre.ethers.getSigners();
    return new Contract(proxyAddress, combinedAbi, signer);
  }

  // Not proxied: direct lookup
  const entry = findEntry(nsRegistry, name);
  if (!entry) {
    throw new Error(
      `Contract "${name}" not found in registry (chain=${chainId}, namespace="${namespace}")`
    );
  }

  const artifactName = opts.implArtifact ?? name;
  const { abi } = getForgeArtifact(artifactName);
  const [signer] = await hre.ethers.getSigners();
  return new Contract(entry.address, abi, signer);
}

/**
 * Run a callback as a specific treb sender.
 *
 * If the sender has a private key, a Wallet signer is used directly.
 * Otherwise, the sender's address is impersonated via hardhat_impersonateAccount.
 */
export async function runAs<T>(
  senderName: string,
  fn: (sender: Awaited<ReturnType<typeof hre.ethers.getSigner>>) => Promise<T>
): Promise<T> {
  const senderConfig = trebRuntime.senders[senderName];
  if (!senderConfig) {
    throw new Error(
      `Unknown sender "${senderName}". Available: ${Object.keys(trebRuntime.senders).join(", ")}`
    );
  }

  if ("privateKey" in senderConfig) {
    const wallet = new Wallet(
      senderConfig.privateKey,
      hre.ethers.provider
    );
    return fn(wallet as any);
  }

  // Impersonate
  const address = senderConfig.address;
  await hre.ethers.provider.send("hardhat_impersonateAccount", [address]);
  try {
    const signer = await hre.ethers.getSigner(address);
    return await fn(signer);
  } finally {
    await hre.ethers.provider.send("hardhat_stopImpersonatingAccount", [
      address,
    ]);
  }
}

/**
 * Merge two ABIs, deduplicating by signature.
 * Implementation ABI takes priority over proxy ABI for conflicts.
 */
function mergeAbis(proxyAbi: InterfaceAbi, implAbi: InterfaceAbi): any[] {
  const seen = new Set<string>();
  const result: any[] = [];

  // Implementation ABI first (takes priority)
  for (const item of implAbi as any[]) {
    const sig = abiItemSignature(item);
    if (sig && !seen.has(sig)) {
      seen.add(sig);
      result.push(item);
    }
  }

  // Then proxy ABI (only add if not already present)
  for (const item of proxyAbi as any[]) {
    const sig = abiItemSignature(item);
    if (sig && !seen.has(sig)) {
      seen.add(sig);
      result.push(item);
    }
  }

  return result;
}

function abiItemSignature(item: any): string | null {
  if (item.type === "function" || item.type === "event" || item.type === "error") {
    return `${item.type}:${item.name}`;
  }
  if (item.type === "constructor" || item.type === "fallback" || item.type === "receive") {
    return item.type;
  }
  return null;
}
