#!/usr/bin/env node
// Renames the `## [Unreleased]` section in packages/contracts/CHANGELOG.md to
// `## [<version>] - <date>` and inserts a fresh empty [Unreleased] above it.
// Invoked from packages/contracts' npm `version` lifecycle hook so each
// `npm version <bump>` ships a CHANGELOG entry alongside the version commit.
//
// Usage: node scripts/release-changelog.mjs <version>
// (uses pure Node — no tsx — so it runs from packages/contracts/ without
//  needing the root devDependencies on PATH.)

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const version = process.argv[2];
if (!version) {
  console.error("Usage: release-changelog.mjs <version>");
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
if (!trimmedSection) {
  console.warn(
    `⚠  CHANGELOG.md [Unreleased] is empty — releasing ${version} with no entries.`,
  );
}

const newBody =
  body.slice(0, idx) +
  `${UNRELEASED}\n\n## [${version}] - ${today}\n\n${trimmedSection}${trimmedSection ? "\n" : ""}${tail}`;

writeFileSync(changelogPath, newBody);
console.log(`✓ CHANGELOG.md: [Unreleased] → [${version}] - ${today}`);
