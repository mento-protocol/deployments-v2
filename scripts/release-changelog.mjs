#!/usr/bin/env node
// Renames the `## [Unreleased]` section in packages/contracts/CHANGELOG.md to
// `## [<version>] - <date>` and inserts a fresh empty [Unreleased] above it.
// Invoked from packages/contracts' npm `version` lifecycle hook so each
// `npm version <bump>` ships a CHANGELOG entry alongside the version commit.
//
// Usage: node scripts/release-changelog.mjs <version> [--allow-empty]
// (uses pure Node — no tsx — so it runs from packages/contracts/ without
//  needing the root devDependencies on PATH.)
//
// Exit codes:
//   0  rename succeeded (or no-op when CHANGELOG.md / [Unreleased] missing)
//   1  caller error (no version, or version already exists in CHANGELOG)
//   2  empty [Unreleased] without --allow-empty (refuses to ship empty entry)

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const allowEmpty = args.includes("--allow-empty");
const version = args.find((a) => !a.startsWith("--"));

if (!version) {
  console.error("Usage: release-changelog.mjs <version> [--allow-empty]");
  process.exit(1);
}

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const changelogPath = join(repoRoot, "packages", "contracts", "CHANGELOG.md");

const UNRELEASED = "## [Unreleased]";
const today = new Date().toISOString().slice(0, 10);

if (!existsSync(changelogPath)) {
  console.warn(`⚠  No CHANGELOG.md at ${changelogPath} — skipping rename.`);
  process.exit(0);
}

const body = readFileSync(changelogPath, "utf8");

// Refuse to overwrite an already-released version. Catches the
// `npm version <samevsame>` foot-gun and the case where someone already
// hand-renamed [Unreleased] → [X] and then runs the hook again.
const existingHeading = new RegExp(`^## \\[${escapeRegex(version)}\\]`, "m");
if (existingHeading.test(body)) {
  console.error(
    `✖  CHANGELOG.md already has a "## [${version}]" heading. ` +
      `Refusing to insert a duplicate. ` +
      `If this is intentional, edit CHANGELOG.md by hand and re-run.`,
  );
  process.exit(1);
}

const idx = body.indexOf(UNRELEASED);
if (idx === -1) {
  console.warn(
    `⚠  No "${UNRELEASED}" heading in CHANGELOG.md — skipping rename.`,
  );
  process.exit(0);
}

// Pull out the [Unreleased] section body (up to the next "## [" or EOF).
const after = body.slice(idx + UNRELEASED.length);
const nextMatch = after.match(/\n## \[/);
const sectionBody = nextMatch ? after.slice(0, nextMatch.index) : after;
const tail = nextMatch ? after.slice(nextMatch.index) : "";

const trimmedSection = sectionBody.replace(/^\n+|\n+$/g, "");
if (!trimmedSection && !allowEmpty) {
  console.error(
    `✖  CHANGELOG.md [Unreleased] is empty — refusing to ship an empty release entry.\n` +
      `   Either:\n` +
      `     - Run \`npm run contracts:update\` first (populates [Unreleased] from the regen diff), or\n` +
      `     - Add a manual entry to [Unreleased] before bumping, or\n` +
      `     - Re-run with --allow-empty if you really want an empty section ` +
      `(rare; only meaningful for metadata-only releases).`,
  );
  process.exit(2);
}

const newBody =
  body.slice(0, idx) +
  `${UNRELEASED}\n\n## [${version}] - ${today}\n\n${trimmedSection}${trimmedSection ? "\n" : ""}${tail}`;

writeFileSync(changelogPath, newBody);
console.log(`✓ CHANGELOG.md: [Unreleased] → [${version}] - ${today}`);

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
