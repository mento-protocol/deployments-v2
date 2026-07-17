import { describe, expect, it } from "vitest";
import {
  diffContractsJson,
  publishedNamespaces,
} from "./check-namespace-drift";

const committed = {
  "137": {
    mainnet: {
      Router: { address: "0xAAA", type: "PROXY" },
    },
  },
  "11142220": {
    "testnet-v2-rc5": {
      Reserve: { address: "0xBBB", type: "PROXY" },
    },
  },
};

describe("publishedNamespaces", () => {
  it("returns the sorted union of namespaces across chains", () => {
    expect(publishedNamespaces(committed)).toEqual([
      "mainnet",
      "testnet-v2-rc5",
    ]);
  });
});

describe("diffContractsJson", () => {
  it("reports no drift when regenerated equals committed", () => {
    const { missing, changed } = diffContractsJson(committed, committed);
    expect(missing).toEqual([]);
    expect(changed).toEqual([]);
  });

  it("flags a key present in regenerated but missing from committed", () => {
    const regenerated = {
      ...committed,
      "137": {
        mainnet: {
          Router: { address: "0xAAA", type: "PROXY" },
          NewOracle: { address: "0xCCC", type: "SINGLETON" },
        },
      },
    };
    const { missing, changed } = diffContractsJson(committed, regenerated);
    expect(changed).toEqual([]);
    expect(missing).toEqual([
      {
        chainId: "137",
        namespace: "mainnet",
        name: "NewOracle",
        address: "0xCCC",
      },
    ]);
  });

  it("flags a re-pointed address, case-insensitively stable", () => {
    const regenerated = {
      ...committed,
      "137": { mainnet: { Router: { address: "0xDDD", type: "PROXY" } } },
    };
    const { missing, changed } = diffContractsJson(committed, regenerated);
    expect(missing).toEqual([]);
    expect(changed).toEqual([
      {
        chainId: "137",
        namespace: "mainnet",
        name: "Router",
        address: "0xDDD",
        committedAddress: "0xAAA",
      },
    ]);
  });

  it("treats address casing as equal (no false drift)", () => {
    const regenerated = {
      ...committed,
      "137": { mainnet: { Router: { address: "0xaaa", type: "PROXY" } } },
    };
    const { missing, changed } = diffContractsJson(committed, regenerated);
    expect(missing).toEqual([]);
    expect(changed).toEqual([]);
  });

  it("ignores committed-only keys (additive-only, reverse drift out of scope)", () => {
    const regenerated = {
      "137": { mainnet: { Router: { address: "0xAAA", type: "PROXY" } } },
      // testnet-v2-rc5 Reserve dropped from regen — must NOT be flagged
    };
    const { missing, changed } = diffContractsJson(committed, regenerated);
    expect(missing).toEqual([]);
    expect(changed).toEqual([]);
  });
});
