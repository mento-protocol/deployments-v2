import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  unlinkSync,
  writeFileSync,
} from "fs";
import { basename, dirname, join } from "path";
import { createInterface } from "readline";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";

// ─── Types ────────────────────────────────────────────────────────────────────

interface DeploymentEntry {
  id: string;
  namespace: string;
  chainId: number;
  contractName: string;
  label: string | null;
  address: string;
  type: "SINGLETON" | "PROXY" | "LIBRARY";
  proxyInfo: {
    implementation: string;
    history: string[];
  } | null;
  artifact: {
    path: string;
    compilerVersion: string;
    scriptPath: string;
  } | null;
}

type ContractType = "token" | "pool" | "contract";

interface ContractEntry {
  address: string;
  type: ContractType;
  decimals?: number;
}

type ContractsJson = Record<
  string,
  Record<string, Record<string, ContractEntry>>
>;
type AddressBook = Record<string, Record<string, string>>;

interface ResolvedContract {
  trebKey: string;
  exportName: string;
  address: string;
  chainId: number;
  namespace: string;
  abi: unknown[];
}

// ─── Paths ────────────────────────────────────────────────────────────────────

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");
const trebDir = join(repoRoot, ".treb");
const outDir = join(repoRoot, "out");
const packagesDir = join(repoRoot, "packages", "contracts");
const contractsJsonPath = join(packagesDir, "contracts.json");
const abisDir = join(packagesDir, "abis");
const srcDir = join(packagesDir, "src");
const pkgJsonPath = join(packagesDir, "package.json");

// ─── Helpers ──────────────────────────────────────────────────────────────────

function prompt(question: string): Promise<string> {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function sanitizeName(name: string): string {
  // Remove dots, colons, and slashes that would make invalid JS identifiers or
  // create nested paths (e.g. "AUSD/USD" → "AUSDUSD")
  return name.replace(/\./g, "").replace(/:/g, "").replace(/\//g, "");
}

function ensureDirFor(path: string): void {
  const dir = dirname(path);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

function safeWriteFile(path: string, content: string, context: string): void {
  try {
    ensureDirFor(path);
    writeFileSync(path, content);
  } catch (err) {
    const isEnoent =
      err instanceof Error &&
      "code" in err &&
      (err as NodeJS.ErrnoException).code === "ENOENT";
    const msg = isEnoent
      ? `Parent directory does not exist for ${path}. Ensure the export name does not contain path separators.`
      : `Failed to write ${context} at ${path}`;
    const wrapped = new Error(
      `${msg}${err instanceof Error ? `\n  Cause: ${err.message}` : ""}`,
    );
    if (err instanceof Error) {
      (wrapped as Error & { cause?: unknown }).cause = err;
    }
    throw wrapped;
  }
}

function deriveExportName(
  entry: DeploymentEntry,
  overrides: Record<string, string>,
  includeLabel = false,
): string {
  const trebKey = entry.contractName + (entry.label ? `:${entry.label}` : "");

  if (overrides[trebKey]) {
    return overrides[trebKey];
  }

  if (
    entry.contractName === "Proxy" ||
    entry.contractName === "TransparentUpgradeableProxy"
  ) {
    // Use label but sanitize it
    return sanitizeName(entry.label ?? entry.contractName);
  }

  if (includeLabel && entry.label) {
    return sanitizeName(entry.contractName + entry.label);
  }

  return entry.contractName;
}

function resolveAbiPath(
  entry: DeploymentEntry,
  allEntries: Record<string, DeploymentEntry>,
): { solFile: string; contractName: string } | null {
  let target = entry;

  // For proxies, follow to the implementation to get the right ABI
  if (entry.type === "PROXY" && entry.proxyInfo?.implementation) {
    const implEntry = Object.values(allEntries).find(
      (e) =>
        e.address.toLowerCase() ===
        entry.proxyInfo!.implementation.toLowerCase(),
    );
    if (implEntry) {
      target = implEntry;
    }
  }

  const artifactPath = target.artifact?.path;

  if (artifactPath) {
    // e.g. "lib/mento-core/contracts/swap/FPMMFactory.sol"
    const solFile = basename(artifactPath); // "FPMMFactory.sol"
    return { solFile, contractName: target.contractName };
  }

  // Fallback: assume <ContractName>.sol/<ContractName>.json
  return {
    solFile: `${target.contractName}.sol`,
    contractName: target.contractName,
  };
}

function readAbi(solFile: string, contractName: string): unknown[] | null {
  const artifactPath = join(outDir, solFile, `${contractName}.json`);
  if (!existsSync(artifactPath)) {
    return null;
  }
  const artifact = JSON.parse(readFileSync(artifactPath, "utf8")) as {
    abi: unknown[];
  };
  return artifact.abi ?? null;
}

/**
 * Derives a clean export name from an address book key.
 *
 * Address book keys follow these conventions:
 *   "Proxy:USDm"                         → "USDm"
 *   "TransparentUpgradeableProxy:Broker"  → "Broker"
 *   "BreakerBox:v2.6.5"                   → "BreakerBox"
 *   "USDC"                                → "USDC"
 */
function deriveAddressBookExportName(key: string): string {
  if (key.startsWith("Proxy:")) return sanitizeName(key.slice("Proxy:".length));
  if (key.startsWith("TransparentUpgradeableProxy:"))
    return sanitizeName(key.slice("TransparentUpgradeableProxy:".length));
  const versionMatch = key.match(/^(.+):v\d+\.\d+\.\d+$/);
  if (versionMatch) return sanitizeName(versionMatch[1]);
  return sanitizeName(key);
}

// ─── Token registry ──────────────────────────────────────────────────────────
// Keys are case-sensitive and must match the export name exactly
// (e.g. AUSD on Monad vs aUSD on Celo are distinct tokens).

const KNOWN_TOKENS: Record<string, number> = {
  USDC: 6,
  USDT: 6,
  USDT0: 6,
  axlUSDC: 6,
  axlEUROC: 6,
  EURC: 6,
  AUSD: 6,
  aUSD: 6,
  CELO: 18,
  MentoToken: 18,
};

function getTokenDecimals(name: string): number | null {
  if (name in KNOWN_TOKENS) return KNOWN_TOKENS[name];
  // Mento stablecoins: all [A-Z]{2,5}m tokens are 18 decimals by convention.
  // KNOWN_TOKENS is checked first, so explicit overrides always win.
  if (/^[A-Z]{2,5}m$/.test(name)) return 18;
  // Wormhole NTT spoke variants of Mento stablecoins (e.g. USDmSpoke).
  if (/^[A-Z]{2,5}mSpoke$/.test(name)) return 18;
  // MockERC20* tokens: strip prefix iteratively and look up the underlying.
  if (name.startsWith("MockERC20")) {
    let stripped = name;
    while (stripped.startsWith("MockERC20")) {
      stripped = stripped.slice("MockERC20".length);
    }
    return stripped ? getTokenDecimals(stripped) : null;
  }
  if (name.startsWith("StableToken")) return 18;
  return null;
}

function classifyType(name: string): ContractType {
  // Implementation contracts are never tokens, regardless of name prefix.
  if (name.endsWith("Implementation")) return "contract";

  // Tokens: known decimals, or MockERC20* (always a token even if decimals unknown)
  if (getTokenDecimals(name) !== null || name.startsWith("MockERC20"))
    return "token";

  // FPMM pools (but not FPMMFactory or FPMMProxy)
  if (name === "FPMM") return "pool";
  if (
    name.startsWith("FPMM") &&
    !name.startsWith("FPMMFactory") &&
    !name.startsWith("FPMMProxy")
  ) {
    return "pool";
  }

  return "contract";
}

function attachDecimals(entry: ContractEntry, name: string): void {
  if (entry.type !== "token") return;
  const decimals = getTokenDecimals(name);
  if (decimals !== null) {
    entry.decimals = decimals;
  } else {
    console.warn(
      `⚠  Token "${name}" has no known decimals mapping. ` +
        `Add it to KNOWN_TOKENS in gen-contracts-package.ts.`,
    );
  }
}

function generateTsModule(
  name: string,
  abi: unknown[],
  addresses: Record<string, string>,
  decimals?: number,
): string {
  const abiJson = JSON.stringify(abi, null, 2)
    .split("\n")
    .map((line, i) => (i === 0 ? line : `  ${line}`))
    .join("\n");
  const addressLines = Object.entries(addresses)
    .map(([chainId, addr]) => `    ${chainId}: '${addr}',`)
    .join("\n");
  let output =
    `export const ${name} = {\n` +
    `  abi: ${abiJson} as const,\n` +
    `  address: {\n${addressLines}\n  } as Partial<Record<number, \`0x\${string}\`>>,\n`;

  if (decimals !== undefined) {
    output += `  decimals: ${decimals},\n`;
  }

  output += `};\n`;
  return output;
}

function diffContracts(
  oldJson: ContractsJson,
  newJson: ContractsJson,
): { added: string[]; removed: string[]; changed: string[] } {
  const added: string[] = [];
  const removed: string[] = [];
  const changed: string[] = [];

  const allChains = new Set([...Object.keys(oldJson), ...Object.keys(newJson)]);

  for (const chainId of allChains) {
    const allNs = new Set([
      ...Object.keys(oldJson[chainId] ?? {}),
      ...Object.keys(newJson[chainId] ?? {}),
    ]);
    for (const ns of allNs) {
      const oldNs = oldJson[chainId]?.[ns] ?? {};
      const newNs = newJson[chainId]?.[ns] ?? {};
      const allNames = new Set([...Object.keys(oldNs), ...Object.keys(newNs)]);

      for (const name of allNames) {
        const key = `${chainId}/${ns}/${name}`;
        if (!oldNs[name]) {
          added.push(key);
        } else if (!newNs[name]) {
          removed.push(key);
        } else if (
          oldNs[name].address !== newNs[name].address ||
          oldNs[name].type !== newNs[name].type ||
          oldNs[name].decimals !== newNs[name].decimals
        ) {
          const parts: string[] = [];
          if (oldNs[name].address !== newNs[name].address) {
            parts.push(`${oldNs[name].address} → ${newNs[name].address}`);
          }
          if (oldNs[name].type !== newNs[name].type) {
            parts.push(`type: ${oldNs[name].type} → ${newNs[name].type}`);
          }
          if (oldNs[name].decimals !== newNs[name].decimals) {
            parts.push(
              `decimals: ${oldNs[name].decimals ?? "unset"} → ${newNs[name].decimals ?? "unset"}`,
            );
          }
          changed.push(`${key}: ${parts.join(", ")}`);
        }
      }
    }
  }

  return { added, removed, changed };
}

function sortContractsByNamespace(contracts: ContractsJson): ContractsJson {
  const sorted: ContractsJson = {};
  for (const [chainId, namespaces] of Object.entries(contracts)) {
    sorted[chainId] = {};
    for (const [ns, contractEntries] of Object.entries(namespaces)) {
      const sortedEntries: Record<string, ContractEntry> = {};
      for (const name of Object.keys(contractEntries).sort()) {
        sortedEntries[name] = contractEntries[name];
      }
      sorted[chainId][ns] = sortedEntries;
    }
  }
  return sorted;
}

// ─── Namespace selection ──────────────────────────────────────────────────────

async function selectNamespace(
  deployments: Record<string, DeploymentEntry>,
): Promise<string> {
  // Positional arg or --namespace= flag
  const positional = process.argv.slice(2).find((a) => !a.startsWith("--"));
  if (positional) return positional;

  const flagArg = process.argv
    .slice(2)
    .find((a) => a.startsWith("--namespace="));
  if (flagArg) return flagArg.split("=")[1];

  // Interactive prompt
  const namespaces = [
    ...new Set(Object.values(deployments).map((e) => e.namespace)),
  ].sort();

  console.log("\nAvailable namespaces:");
  namespaces.forEach((ns, i) => console.log(`  ${i + 1}. ${ns}`));

  const answer = await prompt("\nSelect namespace (number or name): ");
  const idx = parseInt(answer, 10);
  if (!isNaN(idx) && idx >= 1 && idx <= namespaces.length) {
    return namespaces[idx - 1];
  }
  if (namespaces.includes(answer)) return answer;

  console.error(`Unknown selection: "${answer}"`);
  process.exit(1);
}

// ─── Prerequisites ────────────────────────────────────────────────────────────

async function ensureFoundryArtifacts(): Promise<void> {
  if (existsSync(outDir) && readdirSync(outDir).length > 0) return;

  console.warn(
    "\n⚠  Foundry artifacts not found (out/ directory is missing or empty).",
  );
  console.warn("   ABIs are read from compiled contract artifacts.\n");

  const answer = await prompt("Run forge build now? (Y/n): ");
  if (answer.toLowerCase() === "n") {
    console.error("\nRun `forge build` first, then re-run this script.");
    process.exit(1);
  }

  console.log("\nRunning forge build...\n");
  const result = spawnSync("forge", ["build"], {
    cwd: repoRoot,
    stdio: "inherit",
  });

  if (result.status !== 0) {
    console.error("\nforge build failed. Fix the errors above and try again.");
    process.exit(1);
  }

  console.log("");
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const deploymentsPath = join(trebDir, "deployments.json");
  if (!existsSync(deploymentsPath)) {
    console.error(`deployments.json not found at ${deploymentsPath}`);
    process.exit(1);
  }

  const allDeployments: Record<string, DeploymentEntry> = JSON.parse(
    readFileSync(deploymentsPath, "utf8"),
  );

  const namespace = await selectNamespace(allDeployments);
  const entries = Object.values(allDeployments).filter(
    (e) => e.namespace === namespace,
  );

  if (entries.length === 0) {
    console.error(`No entries found for namespace "${namespace}"`);
    process.exit(1);
  }

  // The "virtual" namespace holds fork/simulation deployments (pre-MGP-14 state,
  // Base fork addresses, etc.) that do not match on-chain reality. Regenerating
  // the package against it overwrites canonical hub addresses with fork addresses
  // and downgrades ABIs (e.g. V3 → V2 for StableToken). Refuse by default.
  if (namespace === "virtual") {
    console.error(
      `\n✖  The "virtual" namespace contains fork/simulation deployments, not on-chain reality.\n` +
        `   Running the generator against it will overwrite canonical contract addresses and ABIs\n` +
        `   with stale fork data (e.g. StableTokenV2 addresses/ABI for proxies that are upgraded to V3).\n` +
        `   Use "mainnet", "monad-mainnet", or "testnet-v2-rc5" instead.`,
    );
    process.exit(1);
  }

  const chainIds = [...new Set(entries.map((e) => String(e.chainId)))];
  if (chainIds.length > 1) {
    console.warn(
      `⚠  Namespace "${namespace}" spans multiple chain IDs: ${chainIds.join(", ")}`,
    );
  }

  console.log(
    `\nProcessing namespace "${namespace}" (chain ${chainIds.join(", ")}, ${entries.length} entries)`,
  );

  await ensureFoundryArtifacts();

  const overrides: Record<string, string> = JSON.parse(
    readFileSync(
      join(repoRoot, "scripts", "contract-name-overrides.json"),
      "utf8",
    ),
  );

  // ── Validate overrides are still referenced ────────────────────────────────

  // Collect every treb key that actually exists in this namespace so we can
  // warn about override entries that no longer match any deployment.
  const allTrebKeys = new Set(
    entries.map((e) => e.contractName + (e.label ? `:${e.label}` : "")),
  );
  const deadOverrides = Object.keys(overrides).filter(
    (k) => !allTrebKeys.has(k),
  );
  if (deadOverrides.length > 0) {
    console.warn(
      `\n⚠  Dead override keys in contract-name-overrides.json (no matching deployment in "${namespace}"):`,
    );
    for (const k of deadOverrides) {
      console.warn(`   - "${k}" → "${overrides[k]}"`);
    }
    console.warn(
      "   These keys have no effect and should be removed if they are no longer needed.\n",
    );
  }

  // ── Resolve all contracts ──────────────────────────────────────────────────

  // First pass: detect which contractNames are non-unique within this namespace,
  // so we can include the label in their export name.
  const contractNameCount = new Map<string, number>();
  for (const entry of entries) {
    contractNameCount.set(
      entry.contractName,
      (contractNameCount.get(entry.contractName) ?? 0) + 1,
    );
  }

  // Sort so PROXY entries come before SINGLETONs/LIBRARIEs. This ensures that
  // when a proxy and its implementation derive to the same export name, the proxy
  // wins — which is correct since consumers call the proxy address (with the
  // implementation's ABI, resolved by resolveAbiPath).
  const sortedEntries = [...entries].sort((a, b) => {
    const isProxyA = a.type === "PROXY" ? 0 : 1;
    const isProxyB = b.type === "PROXY" ? 0 : 1;
    return isProxyA - isProxyB;
  });

  const resolved: ResolvedContract[] = [];
  const superseded: string[] = [];
  const missingAbi: {
    trebKey: string;
    exportName: string;
    address: string;
    chainId: number;
  }[] = [];
  const exportNamesSeen = new Map<
    string,
    { trebKey: string; artifactKey: string; chainId: number }
  >();
  // Deployments sharing an export name + artifact across *different* chains are
  // legitimate (same contract, multi-chain). Record their addresses so the
  // resulting address map covers every chain, even though we only regenerate
  // the ABI once (from the first-resolved entry).
  const crossChainDuplicates: {
    exportName: string;
    address: string;
    chainId: number;
  }[] = [];
  // When contract-name-overrides.json rewrites an entry's export name (e.g.
  // "TransparentUpgradeableProxy:USDm" → "USDmSpoke"), the name that would have
  // been produced without the override may still be sitting in contracts.json
  // from an earlier generator run. Track those so we can evict them after merge.
  const preOverrideRenames: {
    chainId: number;
    namespace: string;
    oldName: string;
  }[] = [];

  for (const entry of sortedEntries) {
    const trebKey = entry.contractName + (entry.label ? `:${entry.label}` : "");

    // Non-unique contractNames include the label for disambiguation
    const isNonUnique = (contractNameCount.get(entry.contractName) ?? 0) > 1;
    const exportName = deriveExportName(entry, overrides, isNonUnique);
    const noOverrideName = deriveExportName(entry, {}, isNonUnique);
    if (noOverrideName !== exportName) {
      preOverrideRenames.push({
        chainId: entry.chainId,
        namespace,
        oldName: noOverrideName,
      });
    }

    const abiTarget = resolveAbiPath(entry, allDeployments);
    if (!abiTarget) {
      missingAbi.push({
        trebKey,
        exportName,
        address: entry.address,
        chainId: entry.chainId,
      });
      continue;
    }
    const artifactKey = `${abiTarget.solFile}:${abiTarget.contractName}`;

    // Guard against remaining collisions (e.g., after override merges two different
    // treb keys to the same friendly name). Since proxies are sorted first, the
    // loser here is usually the implementation singleton — which is superseded
    // by its proxy (same underlying artifact) and intentionally not included.
    // If two deployments resolve to the same export name but different artifacts
    // (e.g. a hub-and-spoke token where one chain uses StableTokenV2 and another
    // uses StableTokenSpoke), fail loudly so the operator adds a disambiguating
    // entry to contract-name-overrides.json.
    const prior = exportNamesSeen.get(exportName);
    if (prior) {
      if (prior.artifactKey === artifactKey) {
        if (prior.chainId === entry.chainId) {
          // Same chain + same artifact = proxy-vs-implementation dedup.
          // Drop entirely — consumers want the proxy address, not the impl.
          superseded.push(trebKey);
        } else {
          // Different chain + same artifact = legitimate multi-chain deployment.
          // Keep the address; the ABI was already recorded by the first entry.
          crossChainDuplicates.push({
            exportName,
            address: entry.address,
            chainId: entry.chainId,
          });
        }
        continue;
      }
      throw new Error(
        `Export name collision on "${exportName}" with divergent implementations:\n` +
          `  "${prior.trebKey}" → ${prior.artifactKey}\n` +
          `  "${trebKey}" → ${artifactKey}\n` +
          `Add a disambiguating entry to scripts/contract-name-overrides.json so each export maps to a single implementation.`,
      );
    }
    exportNamesSeen.set(exportName, {
      trebKey,
      artifactKey,
      chainId: entry.chainId,
    });

    const abi = readAbi(abiTarget.solFile, abiTarget.contractName);
    if (!abi) {
      missingAbi.push({
        trebKey,
        exportName,
        address: entry.address,
        chainId: entry.chainId,
      });
      continue;
    }

    resolved.push({
      trebKey,
      exportName,
      address: entry.address,
      chainId: entry.chainId,
      namespace,
      abi,
    });
  }

  if (resolved.length === 0) {
    console.error(
      "No contracts could be resolved. Make sure forge build has been run.",
    );
    process.exit(1);
  }

  // ── Prepare output directories ─────────────────────────────────────────────

  mkdirSync(packagesDir, { recursive: true });
  mkdirSync(abisDir, { recursive: true });
  mkdirSync(srcDir, { recursive: true });

  // ── Load existing contracts.json for merge ─────────────────────────────────

  const existingContracts: ContractsJson = existsSync(contractsJsonPath)
    ? (JSON.parse(readFileSync(contractsJsonPath, "utf8")) as ContractsJson)
    : {};

  // Deep clone for diff comparison
  const previousContracts: ContractsJson = JSON.parse(
    JSON.stringify(existingContracts),
  );

  // ── Merge new entries into contracts.json ──────────────────────────────────

  const newContracts: ContractsJson = JSON.parse(
    JSON.stringify(existingContracts),
  );

  // Reclassify and backfill decimals on existing entries from prior runs.
  // This corrects entries that were misclassified in older generator versions
  // (e.g. USDT0 was "contract" but is now a known token).
  for (const namespaces of Object.values(newContracts)) {
    for (const contracts of Object.values(namespaces)) {
      for (const [name, entry] of Object.entries(contracts)) {
        const correctType = classifyType(name);
        if (entry.type !== correctType) {
          entry.type = correctType;
        }
        if (entry.type === "token" && entry.decimals === undefined) {
          attachDecimals(entry, name);
        }
      }
    }
  }

  // Track which (chainId, namespace, exportName) tuples this run wrote so the
  // missingAbi and cross-chain injection steps can distinguish "wrote this run"
  // from "carried over from previous state" and avoid stale data.
  const writtenThisRun = new Set<string>();
  const markWritten = (chainId: string, ns: string, name: string) =>
    writtenThisRun.add(`${chainId}:${ns}:${name}`);
  const wasWrittenThisRun = (chainId: string, ns: string, name: string) =>
    writtenThisRun.has(`${chainId}:${ns}:${name}`);

  for (const contract of resolved) {
    const chainId = String(contract.chainId);
    newContracts[chainId] ??= {};
    newContracts[chainId][contract.namespace] ??= {};
    const type = classifyType(contract.exportName);
    const entry: ContractEntry = { address: contract.address, type };
    attachDecimals(entry, contract.exportName);
    newContracts[chainId][contract.namespace][contract.exportName] = entry;
    markWritten(chainId, contract.namespace, contract.exportName);
  }

  // Same contract deployed on additional chains in this namespace — record the
  // address (ABI already emitted by the first-resolved entry).
  for (const d of crossChainDuplicates) {
    const chainId = String(d.chainId);
    newContracts[chainId] ??= {};
    newContracts[chainId][namespace] ??= {};
    const type = classifyType(d.exportName);
    const entry: ContractEntry = { address: d.address, type };
    attachDecimals(entry, d.exportName);
    newContracts[chainId][namespace][d.exportName] = entry;
    markWritten(chainId, namespace, d.exportName);
  }

  // Evict entries that exist in contracts.json only because an earlier generator
  // run produced them under the pre-override export name (e.g. a Monad spoke
  // deployment produced "USDm" before "TransparentUpgradeableProxy:USDm" →
  // "USDmSpoke" was added to contract-name-overrides.json). The current run
  // produces the override name instead, leaving the pre-override name stale.
  for (const r of preOverrideRenames) {
    const chainId = String(r.chainId);
    const partition = newContracts[chainId]?.[r.namespace];
    if (partition && partition[r.oldName]) {
      delete partition[r.oldName];
    }
  }

  // Preserve addresses for contracts the run saw but couldn't resolve an ABI for
  // (forge didn't compile the impl, artifact JSON missing, etc.). Overwrite the
  // address if the prior state had a different one — otherwise a redeployed
  // contract would keep pointing consumers at the old address just because its
  // ABI isn't buildable this run. Skip only if *this* run already wrote a
  // resolved entry at the same (chainId, namespace, exportName).
  for (const m of missingAbi) {
    const chainId = String(m.chainId);
    if (wasWrittenThisRun(chainId, namespace, m.exportName)) continue;
    newContracts[chainId] ??= {};
    newContracts[chainId][namespace] ??= {};
    const type = classifyType(m.exportName);
    const entry: ContractEntry = { address: m.address, type };
    attachDecimals(entry, m.exportName);
    newContracts[chainId][namespace][m.exportName] = entry;
    markWritten(chainId, namespace, m.exportName);
  }

  // ── Merge address book entries ────────────────────────────────────────────
  // The address book contains pre-treb legacy contracts (stablecoins, oracles,
  // governance, etc.) that are not in deployments.json. We inject them into
  // the current namespace so the package covers all protocol contracts.

  const addressBookPath = join(trebDir, "addressbook.json");
  if (existsSync(addressBookPath)) {
    const addressBook: AddressBook = JSON.parse(
      readFileSync(addressBookPath, "utf8"),
    );

    // Only inject into chains that appeared in this namespace's treb entries,
    // so we don't pollute unrelated chains.
    const namespaceChainIds = new Set(entries.map((e) => String(e.chainId)));
    let addressBookInjectedCount = 0;

    for (const [chainId, bookEntries] of Object.entries(addressBook)) {
      if (!namespaceChainIds.has(chainId)) continue;

      // Guard: if this chain has multiple namespaces and the current one is not
      // among them, skip to avoid ambiguity about which namespace to inject into.
      const existingNamespaces = Object.keys(newContracts[chainId] ?? {});
      if (
        existingNamespaces.length > 1 &&
        !existingNamespaces.includes(namespace)
      ) {
        console.warn(
          `\n⚠  Skipping address book injection for chain ${chainId}: ` +
            `multiple namespaces exist (${existingNamespaces.join(", ")}) and ` +
            `"${namespace}" is not among them. Run the correct namespace to inject.\n`,
        );
        continue;
      }

      newContracts[chainId] ??= {};
      newContracts[chainId][namespace] ??= {};

      for (const [key, address] of Object.entries(bookEntries)) {
        // Skip zero/null addresses
        if (!address || /^0x0+$/.test(address)) continue;

        const exportName = deriveAddressBookExportName(key);

        // Treb-deployed entries take precedence
        if (newContracts[chainId][namespace][exportName]) continue;

        const abType = classifyType(exportName);
        const abEntry: ContractEntry = { address, type: abType };
        attachDecimals(abEntry, exportName);
        newContracts[chainId][namespace][exportName] = abEntry;
        addressBookInjectedCount++;

        // Attempt to find an ABI so we can emit a typed TS module.
        // Try <ExportName>.sol/<ExportName>.json in the Foundry out/ directory.
        const abi = readAbi(`${exportName}.sol`, exportName);
        if (abi) {
          resolved.push({
            trebKey: key,
            exportName,
            address,
            chainId: Number(chainId),
            namespace,
            abi,
          });
        }
        // If no ABI found the entry still appears in contracts.json for
        // address labelling, but won't get a typed TS module.
      }
    }

    console.log(
      `\n✓ Merged ${addressBookInjectedCount} address book entries for chain(s): ${[...namespaceChainIds].join(", ")}`,
    );
  }

  // ── Clean up stale artifacts for evicted rename targets ──────────────────
  // After all merges, any preOverrideRenames oldName that no longer appears in
  // newContracts is fully retired — delete its abi/src files so consumers can't
  // import a fossilised ABI for a name the registry no longer recognises. If
  // the oldName still lives in another (chainId, namespace) partition (e.g. a
  // hub-chain deployment under the same export name), we leave the files alone.
  const evictedOldNames = new Set(preOverrideRenames.map((r) => r.oldName));
  if (evictedOldNames.size > 0) {
    const stillLivingNames = new Set<string>();
    for (const namespaces of Object.values(newContracts)) {
      for (const contracts of Object.values(namespaces)) {
        for (const name of Object.keys(contracts)) {
          if (evictedOldNames.has(name)) stillLivingNames.add(name);
        }
      }
    }
    for (const oldName of evictedOldNames) {
      if (stillLivingNames.has(oldName)) continue;
      const abiPath = join(abisDir, `${oldName}.json`);
      const srcPath = join(srcDir, `${oldName}.ts`);
      if (existsSync(abiPath)) unlinkSync(abiPath);
      if (existsSync(srcPath)) unlinkSync(srcPath);
    }
  }

  // ── Write abis/ and src/ ───────────────────────────────────────────────────

  // Build chainId → address map per export name from the complete contracts.json.
  // This must cover ALL namespaces (not just the current run) so that each TS
  // module always has a complete address map after every generator invocation.
  //
  // When the same (exportName, chainId) appears in multiple namespaces with
  // different addresses (e.g. an original Monad deploy in "monad-mainnet" that
  // was later superseded by a redeploy in "mainnet"), prefer the entry from the
  // most recently-active namespace. Recency is approximated by the max
  // updatedAt/createdAt across the namespace's treb entries; namespaces with no
  // treb backing (pure address-book) rank last.
  const namespaceRecency = new Map<string, string>();
  for (const entry of Object.values(allDeployments)) {
    const ts = entry.updatedAt ?? entry.createdAt ?? "";
    const prior = namespaceRecency.get(entry.namespace) ?? "";
    if (ts > prior) namespaceRecency.set(entry.namespace, ts);
  }

  const addressesByName = new Map<string, Record<string, string>>();
  const decimalsByName = new Map<string, number>();
  const addressSource = new Map<string, string>(); // `${name}:${chainId}` → namespace
  for (const [chainId, namespaces] of Object.entries(newContracts)) {
    for (const [ns, contracts] of Object.entries(namespaces)) {
      for (const [name, entry] of Object.entries(contracts)) {
        if (!addressesByName.has(name)) addressesByName.set(name, {});
        const addrKey = `${name}:${chainId}`;
        const existingNs = addressSource.get(addrKey);
        const existingAddr = addressesByName.get(name)![chainId];

        if (existingAddr === undefined || existingAddr === entry.address) {
          addressesByName.get(name)![chainId] = entry.address;
          addressSource.set(addrKey, ns);
        } else {
          // Different addresses across namespaces for the same (name, chainId).
          // Pick the namespace with the newer recency.
          const existingRecency = namespaceRecency.get(existingNs ?? "") ?? "";
          const thisRecency = namespaceRecency.get(ns) ?? "";
          if (thisRecency > existingRecency) {
            console.warn(
              `⚠  Address conflict on "${name}" chain ${chainId}: "${existingNs}"=${existingAddr} vs "${ns}"=${entry.address}. Using "${ns}" (newer namespace).`,
            );
            addressesByName.get(name)![chainId] = entry.address;
            addressSource.set(addrKey, ns);
          } else {
            console.warn(
              `⚠  Address conflict on "${name}" chain ${chainId}: "${existingNs}"=${existingAddr} vs "${ns}"=${entry.address}. Keeping "${existingNs}" (newer namespace).`,
            );
          }
        }

        if (entry.decimals !== undefined) {
          const existing = decimalsByName.get(name);
          if (existing !== undefined && existing !== entry.decimals) {
            console.warn(
              `⚠  Token "${name}" has conflicting decimals: ${existing} vs ${entry.decimals}`,
            );
          }
          if (existing === undefined) {
            decimalsByName.set(name, entry.decimals);
          }
        }
      }
    }
  }

  // Collect all unique export names across the whole contracts.json.
  const allExportNames = new Set(addressesByName.keys());

  // Write ABI JSONs for newly resolved contracts.
  for (const contract of resolved) {
    const abiPath = join(abisDir, `${contract.exportName}.json`);
    safeWriteFile(
      abiPath,
      JSON.stringify(contract.abi, null, 2) + "\n",
      `ABI for ${contract.trebKey}`,
    );
  }

  // Regenerate ALL TS modules from the complete state so that address maps
  // stay up-to-date when a new namespace adds a chain to an existing contract.
  // Only names with an ABI file get a typed TS module — address-book-only
  // entries (e.g. CELO, USDC) appear in contracts.json for labelling but not
  // in the typed exports.
  const typedExportNames = new Set<string>();
  for (const name of allExportNames) {
    const abiPath = join(abisDir, `${name}.json`);
    if (!existsSync(abiPath)) continue;
    typedExportNames.add(name);
    const abi = JSON.parse(readFileSync(abiPath, "utf8")) as unknown[];
    const addresses = addressesByName.get(name) ?? {};
    const srcPath = join(srcDir, `${name}.ts`);
    safeWriteFile(
      srcPath,
      generateTsModule(name, abi, addresses, decimalsByName.get(name)),
      `TS module for ${name}`,
    );
  }

  // ── Generate src/index.ts barrel ──────────────────────────────────────────

  const indexLines = [...typedExportNames]
    .sort()
    .map((name) => `export * from "./${name}.js";`);
  safeWriteFile(
    join(srcDir, "index.ts"),
    indexLines.join("\n") + "\n",
    "barrel index",
  );

  // ── Write contracts.json ───────────────────────────────────────────────────

  safeWriteFile(
    contractsJsonPath,
    JSON.stringify(sortContractsByNamespace(newContracts), null, 2) + "\n",
    "contracts.json",
  );

  // ── Update packages/contracts/package.json exports ────────────────────────

  const pkgJsonTemplate: Record<string, unknown> = existsSync(pkgJsonPath)
    ? (JSON.parse(readFileSync(pkgJsonPath, "utf8")) as Record<string, unknown>)
    : {
        name: "@mento-protocol/contracts",
        version: "0.1.0",
        description: "Mento protocol contract ABIs and addresses",
        type: "module",
        main: "./dist/index.js",
        types: "./dist/index.d.ts",
        scripts: { build: "tsc" },
        keywords: ["mento", "contracts", "abis"],
        license: "LGPL-3.0",
      };

  // Always enforce these fields so they survive incremental updates.
  pkgJsonTemplate.files = ["dist", "abis", "contracts.json", "README.md"];
  pkgJsonTemplate.sideEffects = false;

  const exportsMap: Record<string, unknown> = {
    ".": {
      types: "./dist/index.d.ts",
      import: "./dist/index.js",
    },
    "./contracts.json": "./contracts.json",
    "./abis/*": "./abis/*",
  };

  for (const name of typedExportNames) {
    exportsMap[`./${name}`] = {
      types: `./dist/${name}.d.ts`,
      import: `./dist/${name}.js`,
    };
  }

  pkgJsonTemplate.exports = exportsMap;

  safeWriteFile(
    pkgJsonPath,
    JSON.stringify(pkgJsonTemplate, null, 2) + "\n",
    "package.json",
  );

  // ── Format generated output so it survives the trunk/prettier CI check ────
  // The generator serialises ABIs via JSON.stringify which leaves keys quoted;
  // prettier wants unquoted TS-style keys. Rather than re-implement a TS-object
  // serialiser, run trunk fmt over the generated files. Skip silently if trunk
  // isn't on PATH — the CI will still flag the formatting issue.
  const fmtTargets = [srcDir, abisDir, contractsJsonPath, pkgJsonPath];
  const fmtResult = spawnSync("trunk", ["fmt", ...fmtTargets], {
    cwd: repoRoot,
    stdio: "ignore",
  });
  if (fmtResult.status === 0) {
    console.log("✓ Formatted generated files via trunk fmt");
  } else if (
    fmtResult.error &&
    "code" in fmtResult.error &&
    fmtResult.error.code === "ENOENT"
  ) {
    console.warn(
      "⚠  trunk not found on PATH — skipping auto-format. Run `trunk fmt` manually before committing.",
    );
  } else {
    console.warn("⚠  trunk fmt exited non-zero; check the output above.");
  }

  // ── Diff and summary ───────────────────────────────────────────────────────

  const { added, removed, changed } = diffContracts(
    previousContracts,
    newContracts,
  );
  const hasChanges =
    added.length > 0 || removed.length > 0 || changed.length > 0;

  console.log(`\n✓ Generated ${resolved.length} contracts`);

  if (missingAbi.length > 0) {
    console.warn(
      `\n⚠  Skipped ${missingAbi.length} contracts (ABI not found in out/, address-only):`,
    );
    for (const m of missingAbi) {
      console.warn(`   - ${m.trebKey}`);
    }
  }

  if (!hasChanges) {
    console.log("\n✓ No changes detected — no new release required.");
    return;
  }

  console.log(
    "\n─── Changes ──────────────────────────────────────────────────",
  );
  if (added.length > 0) {
    console.log(`\n  Added (${added.length}):`);
    for (const a of added) console.log(`    + ${a}`);
  }
  if (removed.length > 0) {
    console.log(`\n  Removed (${removed.length}):`);
    for (const r of removed) console.log(`    - ${r}`);
  }
  if (changed.length > 0) {
    console.log(`\n  Changed (${changed.length}):`);
    for (const c of changed) console.log(`    ~ ${c}`);
  }

  console.log(`
─── Release instructions ─────────────────────────────────────────────────────

  cd packages/contracts
  npm run build          # tsc → dist/
  npm version patch      # or minor / major
  npm publish

──────────────────────────────────────────────────────────────────────────────
`);
}

main().catch((err: unknown) => {
  console.error(err);
  process.exit(1);
});
