import "dotenv/config";
import "@nomicfoundation/hardhat-ethers";

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

const namespaces = treb.ns || {};

const localConfigPath = path.resolve(
  __dirname,
  ".treb/config.local.json"
);

const localConfig = fs.existsSync(localConfigPath)
  ? readJson(localConfigPath)
  : { namespace: "default", network: "hardhat" };

const activeNamespace = localConfig.namespace || "default";
const defaultNetwork = localConfig.network || "hardhat";

function collectSenders(namespaceName: string) {
  const defaultNs = namespaces["default"] || {};
  const activeNs = namespaces[namespaceName] || {};

  const mergedSenders = {
    ...(defaultNs.senders || {}),
    ...(activeNs.senders || {}),
  };

  return mergedSenders;
}

const senders = collectSenders(activeNamespace);

interface PrivateKeySender {
  address: string;
  privateKey: string;
}

interface ImpersonatedSender {
  address: string;
}

type Sender = PrivateKeySender | ImpersonatedSender;

const trebSenders: Record<string, Sender> = {};

for (const [name, sender] of Object.entries<any>(senders)) {
  if (sender.type === "private_key" && sender.private_key) {
    const wallet = new Wallet(sender.private_key);
    trebSenders[name] = {
      address: wallet.address,
      privateKey: sender.private_key,
    };
  }

  if (sender.type === "safe" && sender.safe) {
    trebSenders[name] = { address: sender.safe };
  }

  if (sender.type === "oz_governor") {
    if (sender.timelock) {
      trebSenders[name] = { address: sender.timelock };
    } else if (sender.governor) {
      trebSenders[name] = { address: sender.governor };
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

const config: HardhatUserConfig = {
  defaultNetwork,
  paths: {
    sources: "./__skip__",
    tests: "./test-ts",
    artifacts: "./artifacts-hh",
    cache: "./cache-hh",
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    ...networks,
  },
};

export default config;

export const trebRuntime = {
  namespace: activeNamespace,
  defaultNetwork,
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
