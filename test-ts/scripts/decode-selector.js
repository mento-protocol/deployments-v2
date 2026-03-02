#!/usr/bin/env node
/**
 * Decode a function/error/event selector by searching all Foundry artifacts.
 * Usage: node scripts/decode-selector.js 0x4d4556d8
 */
import fs from 'node:fs';
import path from 'node:path';
import { ethers } from 'ethers';

const outDir = path.resolve(import.meta.dirname, '../../out');
const selector = process.argv[2];

if (!selector) {
  console.error('Usage: node scripts/decode-selector.js <selector>');
  process.exit(1);
}

const results = [];

for (const solDir of fs.readdirSync(outDir)) {
  const solPath = path.join(outDir, solDir);
  if (!fs.statSync(solPath).isDirectory()) continue;

  for (const jsonFile of fs.readdirSync(solPath).filter(f => f.endsWith('.json'))) {
    try {
      const artifact = JSON.parse(fs.readFileSync(path.join(solPath, jsonFile), 'utf8'));
      const abi = artifact.abi;
      if (!Array.isArray(abi)) continue;

      const iface = new ethers.Interface(abi);

      // Check errors
      iface.forEachError((err) => {
        if (err.selector === selector) {
          results.push({ contract: jsonFile.replace('.json', ''), type: 'error', name: err.name, format: err.format('full') });
        }
      });

      // Check functions
      iface.forEachFunction((fn) => {
        if (fn.selector === selector) {
          results.push({ contract: jsonFile.replace('.json', ''), type: 'function', name: fn.name, format: fn.format('full') });
        }
      });

      // Check events (topic hash)
      iface.forEachEvent((evt) => {
        if (evt.topicHash === selector) {
          results.push({ contract: jsonFile.replace('.json', ''), type: 'event', name: evt.name, format: evt.format('full') });
        }
      });
    } catch { }
  }
}

if (results.length === 0) {
  console.log('Not found');
} else {
  // Deduplicate by format
  const seen = new Set();
  for (const r of results) {
    const key = `${r.type}:${r.format}`;
    if (seen.has(key)) continue;
    seen.add(key);
    console.log(`[${r.type}] ${r.format}  (${r.contract})`);
  }
}
