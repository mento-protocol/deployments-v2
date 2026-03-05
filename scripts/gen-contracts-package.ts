import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
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
}

// chainId → namespace → contractName → ContractEntry
type ContractsJson = Record<string, Record<string, Record<string, ContractEntry>>>;

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
  // Remove dots and colons that would make invalid JS identifiers / filenames
  return name.replace(/\./g, "").replace(/:/g, "");
}

function deriveExportName(
  entry: DeploymentEntry,
  overrides: Record<string, string>,
  includeLabel = false,
): string {
  const trebKey =
    entry.contractName + (entry.label ? `:${entry.label}` : "");

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
      (e) => e.address.toLowerCase() === entry.proxyInfo!.implementation.toLowerCase(),
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

function classifyType(name: string): ContractType {
  // Implementation contracts are never tokens, regardless of name prefix.
  if (name.endsWith("Implementation")) return "contract";

  // Stablecoins: 2–5 uppercase letters followed by lowercase 'm' (USDm, GBPm…)
  if (/^[A-Z]{2,5}m$/.test(name)) return "token";

  // Known external collateral / ERC-20 tokens
  const knownTokens = new Set([
    "CELO", "USDC", "USDT", "axlUSDC", "axlEUROC", "EURC", "aUSD", "MentoToken",
  ]);
  if (knownTokens.has(name)) return "token";

  // Mock ERC-20s and StableToken implementations (spoke tokens, etc.)
  if (name.startsWith("MockERC20")) return "token";
  if (name.startsWith("StableToken")) return "token";

  // FPMM pools (but not FPMMFactory or FPMMProxy)
  if (name === "FPMM") return "pool";
  if (name.startsWith("FPMM") && !name.startsWith("FPMMFactory") && !name.startsWith("FPMMProxy")) {
    return "pool";
  }

  return "contract";
}

function generateTsModule(
  name: string,
  abi: unknown[],
  addresses: Record<string, string>,
): string {
  const abiJson = JSON.stringify(abi, null, 2)
    .split("\n")
    .map((line, i) => (i === 0 ? line : `    ${line}`))
    .join("\n");
  const addressLines = Object.entries(addresses)
    .map(([chainId, addr]) => `    ${chainId}: '${addr}',`)
    .join("\n");
  return (
    `export const ${name} = {\n` +
    `  abi: ${abiJson} as const,\n` +
    `  address: {\n${addressLines}\n  } as const,\n` +
    `} as const;\n`
  );
}

function diffContracts(
  oldJson: ContractsJson,
  newJson: ContractsJson,
): { added: string[]; removed: string[]; changed: string[] } {
  const added: string[] = [];
  const removed: string[] = [];
  const changed: string[] = [];

  const allChains = new Set([
    ...Object.keys(oldJson),
    ...Object.keys(newJson),
  ]);

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
        } else if (oldNs[name].address !== newNs[name].address) {
          changed.push(`${key}: ${oldNs[name].address} → ${newNs[name].address}`);
        }
      }
    }
  }

  return { added, removed, changed };
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
  const superseded: string[] = []; // lost name collision to a proxy — expected, no warning
  const missingAbi: string[] = []; // could not find ABI in out/ — worth reporting
  const exportNamesSeen = new Map<string, string>(); // exportName → trebKey

  for (const entry of sortedEntries) {
    const trebKey =
      entry.contractName + (entry.label ? `:${entry.label}` : "");

    // Non-unique contractNames include the label for disambiguation
    const isNonUnique = (contractNameCount.get(entry.contractName) ?? 0) > 1;
    const exportName = deriveExportName(entry, overrides, isNonUnique);

    // Guard against remaining collisions (e.g., after override merges two different
    // treb keys to the same friendly name). Since proxies are sorted first, the
    // loser here is always the implementation singleton — which is superseded by
    // its proxy and intentionally not included.
    if (exportNamesSeen.has(exportName)) {
      superseded.push(trebKey);
      continue;
    }
    exportNamesSeen.set(exportName, trebKey);

    const abiTarget = resolveAbiPath(entry, allDeployments);
    if (!abiTarget) {
      missingAbi.push(trebKey);
      continue;
    }

    const abi = readAbi(abiTarget.solFile, abiTarget.contractName);
    if (!abi) {
      missingAbi.push(trebKey);
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

  for (const contract of resolved) {
    const chainId = String(contract.chainId);
    newContracts[chainId] ??= {};
    newContracts[chainId][contract.namespace] ??= {};
    newContracts[chainId][contract.namespace][contract.exportName] = {
      address: contract.address,
      type: classifyType(contract.exportName),
    };
  }

  // ── Write abis/ and src/ ───────────────────────────────────────────────────

  // Build chainId → address map per export name from the complete contracts.json.
  // This must cover ALL namespaces (not just the current run) so that each TS
  // module always has a complete address map after every generator invocation.
  const addressesByName = new Map<string, Record<string, string>>();
  for (const [chainId, namespaces] of Object.entries(newContracts)) {
    for (const contracts of Object.values(namespaces)) {
      for (const [name, entry] of Object.entries(contracts)) {
        if (!addressesByName.has(name)) addressesByName.set(name, {});
        addressesByName.get(name)![chainId] = entry.address;
      }
    }
  }

  // Collect all unique export names across the whole contracts.json for
  // generating a complete index.ts and exports map.
  const allExportNames = new Set(addressesByName.keys());

  // Write ABI JSONs for newly resolved contracts.
  for (const contract of resolved) {
    writeFileSync(
      join(abisDir, `${contract.exportName}.json`),
      JSON.stringify(contract.abi, null, 2) + "\n",
    );
  }

  // Regenerate ALL TS modules from the complete state so that address maps
  // stay up-to-date when a new namespace adds a chain to an existing contract.
  for (const name of allExportNames) {
    const abiPath = join(abisDir, `${name}.json`);
    if (!existsSync(abiPath)) continue;
    const abi = JSON.parse(readFileSync(abiPath, "utf8")) as unknown[];
    const addresses = addressesByName.get(name) ?? {};
    writeFileSync(
      join(srcDir, `${name}.ts`),
      generateTsModule(name, abi, addresses),
    );
  }

  // ── Generate src/index.ts barrel ──────────────────────────────────────────

  const indexLines = [...allExportNames]
    .sort()
    .map((name) => `export * from "./${name}.js";`);
  writeFileSync(join(srcDir, "index.ts"), indexLines.join("\n") + "\n");

  // ── Write contracts.json ───────────────────────────────────────────────────

  writeFileSync(
    contractsJsonPath,
    JSON.stringify(newContracts, null, 2) + "\n",
  );

  // ── Update packages/contracts/package.json exports ────────────────────────

  const pkgJsonTemplate = existsSync(pkgJsonPath)
    ? (JSON.parse(readFileSync(pkgJsonPath, "utf8")) as Record<string, unknown>)
    : {
        name: "@mento-protocol/contracts",
        version: "0.1.0",
        description: "Mento protocol contract ABIs and addresses",
        type: "module",
        main: "./dist/index.js",
        types: "./dist/index.d.ts",
        scripts: {
          build: "tsc",
        },
        files: ["dist", "abis", "contracts.json"],
        keywords: ["mento", "contracts", "abis"],
        license: "LGPL-3.0",
      };

  const exportsMap: Record<string, unknown> = {
    ".": {
      types: "./dist/index.d.ts",
      import: "./dist/index.js",
    },
    "./contracts.json": "./contracts.json",
    "./abis/*": "./abis/*",
  };

  for (const name of allExportNames) {
    exportsMap[`./${name}`] = {
      types: `./dist/${name}.d.ts`,
      import: `./dist/${name}.js`,
    };
  }

  pkgJsonTemplate.exports = exportsMap;

  writeFileSync(pkgJsonPath, JSON.stringify(pkgJsonTemplate, null, 2) + "\n");

  // ── Diff and summary ───────────────────────────────────────────────────────

  const { added, removed, changed } = diffContracts(
    previousContracts,
    newContracts,
  );
  const hasChanges = added.length > 0 || removed.length > 0 || changed.length > 0;

  console.log(`\n✓ Generated ${resolved.length} contracts`);

  if (missingAbi.length > 0) {
    console.warn(`\n⚠  Skipped ${missingAbi.length} contracts (ABI not found in out/):`);
    for (const s of missingAbi) {
      console.warn(`   - ${s}`);
    }
  }

  if (!hasChanges) {
    console.log(
      "\n✓ No changes detected — no new release required.",
    );
    return;
  }

  console.log("\n─── Changes ──────────────────────────────────────────────────");
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
