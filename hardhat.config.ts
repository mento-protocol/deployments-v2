import "dotenv/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";

import fs from "fs";
import path from "path";
import TOML from "toml";
import { Wallet } from "ethers";
import type { HardhatUserConfig } from "hardhat/config";

function expandEnv(value: any): any {
  if (typeof value === "string") {
    return value.replace(/\$\{([^}]+)\}/g, (_, name) => {
      const v = process.env[name];
      if (!v) {
        console.warn(`⚠️  Missing env var ${name}`);
        return "";
      }
      return v;
    });
  }

  if (Array.isArray(value)) {
    return value.map(expandEnv);
  }

  if (typeof value === "object" && value !== null) {
    const out: any = {};
    for (const k of Object.keys(value)) {
      out[k] = expandEnv(value[k]);
    }
    return out;
  }

  return value;
}

function readToml(file: string) {
  const content = fs.readFileSync(file, "utf8");
  return expandEnv(TOML.parse(content));
}

function readJson(file: string) {
  const content = fs.readFileSync(file, "utf8");
  return JSON.parse(content);
}

const foundryPath = path.resolve(__dirname, "foundry.toml");
const foundry = readToml(foundryPath);

const rpcEndpoints = foundry.rpc_endpoints || {};

const networks: Record<string, any> = {};

for (const [name, url] of Object.entries(rpcEndpoints)) {
  networks[name] = {
    url,
  };
}

const trebPath = path.resolve(__dirname, "treb.toml");
const treb = readToml(trebPath);

const accounts = treb.accounts || {};
const namespaces = treb.namespace || {};

const localConfigPath = path.resolve(
  __dirname,
  ".treb/config.local.json"
);

const { namespace, network } = fs.existsSync(localConfigPath)
  ? readJson(localConfigPath)
  : { namespace: "default", network: "hardhat" };

// Resolve a sender name to its account config, following references
function resolveAccount(name: string): any {
  const account = accounts[name];
  if (!account) return undefined;
  return account;
}

// Build resolved senders for the active namespace
const nsSenders = namespaces[namespace]?.senders || {};

interface PrivateKeySender {
  address: string;
  privateKey: string;
}

interface ImpersonatedSender {
  address: string;
}

type Sender = PrivateKeySender | ImpersonatedSender;

const trebSenders: Record<string, Sender> = {};

for (const [role, accountName] of Object.entries<any>(nsSenders)) {
  const account = resolveAccount(accountName);
  if (!account) continue;

  if (account.type === "private_key" && account.private_key) {
    const wallet = new Wallet(account.private_key);
    trebSenders[role] = {
      address: wallet.address,
      privateKey: account.private_key,
    };
  }

  if (account.type === "safe" && account.safe) {
    trebSenders[role] = { address: account.safe };
  }

  if (account.type === "oz_governor") {
    if (account.timelock) {
      trebSenders[role] = { address: account.timelock };
    } else if (account.governor) {
      trebSenders[role] = { address: account.governor };
    }
  }
}

for (const net of Object.values<any>(networks)) {
  net.accounts = Array.from(new Set(
    Object.values(trebSenders)
      .filter(s => Boolean((s as PrivateKeySender).privateKey))
      .map(s => (s as PrivateKeySender).privateKey)
  )
  );
}

// Load active treb fork if one exists and use it as the default network.
const forkStatePath = path.resolve(__dirname, ".treb/priv/fork-state.json");
let defaultNetwork = "hardhat";

if (fs.existsSync(forkStatePath)) {
  const forkState = readJson(forkStatePath);
  for (const [name, fork] of Object.entries<any>(forkState.forks || {})) {
    const forkNetworkName = `fork_${name}`;
    networks[forkNetworkName] = {
      url: fork.forkUrl,
      chainId: fork.chainId,
    };
    defaultNetwork = forkNetworkName;
  }
}

const config: HardhatUserConfig = {
  defaultNetwork,
  paths: {
    sources: "./__skip__",
    tests: "./test-ts",
    artifacts: "./artifacts-hh",
    cache: "./cache-hh",
  },
  networks: {
    hardhat: {},
    ...networks,
  },
};

export default config;

export const trebRuntime = {
  namespace,
  network,
  senders: trebSenders
};

/**
 * Load a contract's ABI and bytecode from Foundry's `out/` directory.
 * Usage: const { abi, bytecode } = getForgeArtifact("FPMM");
 */
export function getForgeArtifact(contractName: string) {
  const artifactPath = path.resolve(
    __dirname,
    `out/${contractName}.sol/${contractName}.json`
  );
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  return {
    abi: artifact.abi,
    bytecode: artifact.bytecode?.object ?? artifact.bytecode,
  };
}
