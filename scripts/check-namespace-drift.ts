/**
 * Namespace-drift guard for `@mento-protocol/contracts`.
 *
 * The package is generated from `.treb/deployments.json` by
 * `gen-contracts-package.ts`, run manually one namespace at a time. Any
 * published namespace nobody remembers to regenerate silently drifts: its
 * real on-chain deployments never reach `contracts.json` and nothing notices
 * (see issue #77 — ~88 addresses sat unpublished for two months).
 *
 * This check regenerates every *already-published* namespace into a throwaway
 * copy of the package and fails if the result adds or re-points any address
 * relative to the committed `contracts.json`. Regenerating with the real
 * generator makes it authoritative — it can never disagree with the
 * generator's own filtering rules.
 *
 * The published set is derived from the committed `contracts.json` itself, so
 * ephemeral namespaces (`virtual`, `throwaway`, `test`, superseded RCs) are
 * excluded by construction and a newly-published namespace is guarded the
 * moment it first lands in the package.
 *
 * Drift is checked additive-only (treb ahead of the package). The generator's
 * merge never removes keys, so package-ahead-of-treb is not a failure mode we
 * guard here.
 */
import { spawnSync } from "child_process";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
} from "fs";
import { tmpdir } from "os";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");
const packagesDir = join(repoRoot, "packages", "contracts");
const committedJsonPath = join(packagesDir, "contracts.json");

// contracts.json shape: chainId → namespace → contractName → { address, ... }
type ContractEntry = { address: string; type?: string };
type ContractsJson = Record<
  string,
  Record<string, Record<string, ContractEntry>>
>;

export interface DriftEntry {
  chainId: string;
  namespace: string;
  name: string;
  address: string;
  committedAddress?: string;
}

export interface DriftReport {
  missing: DriftEntry[]; // in regenerated, absent from committed
  changed: DriftEntry[]; // present in both, address differs
}

/** Namespaces already published in the committed package. */
export function publishedNamespaces(committed: ContractsJson): string[] {
  const set = new Set<string>();
  for (const namespaces of Object.values(committed)) {
    for (const ns of Object.keys(namespaces)) set.add(ns);
  }
  return [...set].sort();
}

/**
 * Additive drift only: keys the regenerated package has that the committed one
 * lacks (missing), plus keys whose address the regen changed (changed).
 * Committed-only keys are intentionally ignored — the generator never removes,
 * so package-ahead-of-treb is out of scope.
 */
export function diffContractsJson(
  committed: ContractsJson,
  regenerated: ContractsJson,
): DriftReport {
  const missing: DriftEntry[] = [];
  const changed: DriftEntry[] = [];

  for (const [chainId, namespaces] of Object.entries(regenerated)) {
    for (const [namespace, contracts] of Object.entries(namespaces)) {
      for (const [name, entry] of Object.entries(contracts)) {
        const committedEntry = committed[chainId]?.[namespace]?.[name];
        if (!committedEntry) {
          missing.push({ chainId, namespace, name, address: entry.address });
        } else if (
          committedEntry.address.toLowerCase() !== entry.address.toLowerCase()
        ) {
          changed.push({
            chainId,
            namespace,
            name,
            address: entry.address,
            committedAddress: committedEntry.address,
          });
        }
      }
    }
  }
  return { missing, changed };
}

function regenerateInto(outDir: string, namespace: string): void {
  const tsx = join(repoRoot, "node_modules", ".bin", "tsx");
  const result = spawnSync(
    tsx,
    ["scripts/gen-contracts-package.ts", namespace],
    {
      cwd: repoRoot,
      env: { ...process.env, CONTRACTS_OUT_DIR: outDir },
      encoding: "utf8",
    },
  );
  if (result.status !== 0) {
    // Throw rather than process.exit so main()'s finally still cleans up tmp.
    throw new Error(
      `Regeneration failed for namespace "${namespace}":\n${result.stdout ?? ""}${result.stderr ?? ""}`,
    );
  }
}

function main(): void {
  if (!existsSync(committedJsonPath)) {
    console.error(`contracts.json not found at ${committedJsonPath}`);
    process.exit(1);
  }

  const committed: ContractsJson = JSON.parse(
    readFileSync(committedJsonPath, "utf8"),
  );
  const namespaces = publishedNamespaces(committed);
  console.log(
    `Checking namespace drift for: ${namespaces.join(", ")}\n` +
      `(regenerating each into a temp copy and comparing against the committed package)\n`,
  );

  // Fail fast if out/ is missing: the generator reads ABIs from there and would
  // otherwise hit its interactive "Run forge build now?" prompt, which hangs
  // forever under spawnSync's non-interactive (EOF) stdin.
  const outDir = join(repoRoot, "out");
  if (!existsSync(outDir) || readdirSync(outDir).length === 0) {
    console.error(
      "Foundry artifacts not found (out/ is missing or empty).\n" +
        "Run `forge build` first, then re-run `pnpm contracts:check-drift`.",
    );
    process.exit(1);
  }

  const tmp = mkdtempSync(join(tmpdir(), "contracts-drift-"));
  try {
    // Seed the temp package with only what the generator's merge reads, so the
    // merge base is the committed state. It creates abis/ and src/ itself.
    for (const file of ["contracts.json", "package.json", "CHANGELOG.md"]) {
      const src = join(packagesDir, file);
      if (existsSync(src)) cpSync(src, join(tmp, file));
    }

    for (const namespace of namespaces) regenerateInto(tmp, namespace);

    const regenerated: ContractsJson = JSON.parse(
      readFileSync(join(tmp, "contracts.json"), "utf8"),
    );
    const { missing, changed } = diffContractsJson(committed, regenerated);

    if (missing.length === 0 && changed.length === 0) {
      console.log("✓ No namespace drift — the package is up to date.");
      return;
    }

    console.error(
      "\n✖  Namespace drift detected: `.treb/deployments.json` is ahead of the committed package.\n",
    );
    if (missing.length > 0) {
      console.error(`  Missing from contracts.json (${missing.length}):`);
      for (const e of missing) {
        console.error(
          `    + ${e.namespace}/${e.chainId}/${e.name} → ${e.address}`,
        );
      }
    }
    if (changed.length > 0) {
      console.error(`\n  Re-pointed addresses (${changed.length}):`);
      for (const e of changed) {
        console.error(
          `    ~ ${e.namespace}/${e.chainId}/${e.name}: ${e.committedAddress} → ${e.address}`,
        );
      }
    }
    const affected = [
      ...new Set([...missing, ...changed].map((e) => e.namespace)),
    ].sort();
    console.error(
      `\n  Regenerate and commit the package for the affected namespace(s):\n` +
        affected
          .map((ns) => `    npm run contracts:update -- --namespace=${ns}`)
          .join("\n") +
        "\n",
    );
    // Set the exit code instead of exiting, so the finally cleanup runs first.
    process.exitCode = 1;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// Only run when invoked directly, so tests can import the pure helpers.
const invokedDirectly =
  process.argv[1] && import.meta.url === `file://${process.argv[1]}`;
if (invokedDirectly) {
  try {
    main();
  } catch (err) {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  }
}
