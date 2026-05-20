import { describe, expect, it } from "vitest";
import {
  INSTANCE_GROUPS,
  KIND_PRECEDENCE,
  TOKENS,
  TOKEN,
  sanitizeName,
} from "./gen-contracts-package.ts";

describe("sanitizeName", () => {
  it("strips dots, colons, slashes, and dashes", () => {
    expect(sanitizeName("Foo.Bar")).toBe("FooBar");
    expect(sanitizeName("Foo:Bar")).toBe("FooBar");
    expect(sanitizeName("AUSD/USD")).toBe("AUSDUSD");
    expect(sanitizeName("ActivePool:v3.0.0-CHFm")).toBe("ActivePoolv300CHFm");
  });

  it("leaves valid JS identifier chars untouched", () => {
    expect(sanitizeName("ActivePool")).toBe("ActivePool");
    expect(sanitizeName("USDm")).toBe("USDm");
    expect(sanitizeName("ChainlinkRelayerV1EURUSD")).toBe(
      "ChainlinkRelayerV1EURUSD",
    );
  });

  it("returns empty string for input made entirely of strip-chars", () => {
    // Documents current behavior — caller must guard against empty results.
    expect(sanitizeName(".:./")).toBe("");
    expect(sanitizeName("---")).toBe("");
  });
});

describe("TOKENS allowlist", () => {
  it("contains the currently-deployed Mento stablecoins", () => {
    // Spot-check a few — the full list is in the source.
    expect(TOKENS).toContain("USDm");
    expect(TOKENS).toContain("EURm");
    expect(TOKENS).toContain("CHFm");
    expect(TOKENS).toContain("JPYm");
  });

  it("compiles to a regex group that anchors to all listed tokens", () => {
    const re = new RegExp(`^${TOKEN}$`);
    for (const token of TOKENS) {
      expect(re.test(token)).toBe(true);
    }
  });

  it("rejects plausible-looking but unlisted tokens (security guard)", () => {
    const re = new RegExp(`^${TOKEN}$`);
    // The pre-tightening regex `[A-Z]{2,5}m` would have accepted these.
    expect(re.test("EVILm")).toBe(false);
    expect(re.test("FOOm")).toBe(false);
    expect(re.test("ABCDEm")).toBe(false);
    // Lowercase-prefix tokens like aUSDm — flagged in review as a known gap.
    expect(re.test("aUSDm")).toBe(false);
  });
});

describe("KIND_PRECEDENCE", () => {
  it("orders proxy and primary above impl, impl above legacy", () => {
    expect(KIND_PRECEDENCE.proxy).toBeLessThan(KIND_PRECEDENCE.impl);
    expect(KIND_PRECEDENCE.primary).toBeLessThan(KIND_PRECEDENCE.impl);
    expect(KIND_PRECEDENCE.impl).toBeLessThan(KIND_PRECEDENCE.legacy);
  });

  it("treats proxy and primary as equivalent precedence", () => {
    // A group has at most one of these two kinds, so equal precedence is fine
    // and avoids forcing an artificial tie-break order.
    expect(KIND_PRECEDENCE.proxy).toBe(KIND_PRECEDENCE.primary);
  });
});

describe("INSTANCE_GROUPS", () => {
  it("each group has at least one pattern", () => {
    for (const group of INSTANCE_GROUPS) {
      expect(group.patterns.length).toBeGreaterThan(0);
    }
  });

  it("every pattern's first capture group is the discriminator", () => {
    // Sanity: pattern.regex must have at least one capture group, and
    // matching a known example must produce a non-empty captured string.
    const exampleByBase: Record<string, string> = {
      ChainlinkRelayerV1: "ChainlinkRelayerV1EURUSD",
      ActivePool: "ActivePoolv300CHFm",
      AddressesRegistry: "AddressesRegistryv300GBPm",
      BorrowerOperations: "BorrowerOperationsv300JPYm",
      CollateralRegistry: "CollateralRegistryv300CHFm",
      CollSurplusPool: "CollSurplusPoolv300CHFm",
      DefaultPool: "DefaultPoolv300CHFm",
      GasPool: "GasPoolv300CHFm",
      HintHelpers: "HintHelpersv300CHFm",
      MultiTroveGetter: "MultiTroveGetterv300CHFm",
      SortedTroves: "SortedTrovesv300CHFm",
      TroveManager: "TroveManagerv300CHFm",
      TroveNFT: "TroveNFTv300CHFm",
      MetadataNFT: "MetadataNFTv300CHFm",
      FixedAssetReader: "FixedAssetReaderv300CHFm",
      SSTORE2DataPointer: "SSTORE2DataPointerv300CHFm",
      FXPriceFeed: "FXPriceFeedProxyCHFm",
      SystemParams: "SystemParamsProxyCHFm",
      StabilityPool: "StabilityPoolCHFm",
      NttDeployHelper: "NttDeployHelperUSDm",
    };
    for (const group of INSTANCE_GROUPS) {
      const example = exampleByBase[group.base];
      expect(example, `missing test example for ${group.base}`).toBeDefined();
      const m = example!.match(group.patterns[0].regex);
      expect(m, `${group.base}: ${example} did not match`).not.toBeNull();
      expect(m![1].length).toBeGreaterThan(0);
    }
  });

  it("ChainlinkRelayerV1 pattern doesn't absorb non-pair siblings", () => {
    const re = INSTANCE_GROUPS.find((g) => g.base === "ChainlinkRelayerV1")!
      .patterns[0].regex;
    // These would have matched the pre-tightening `(.+)` regex.
    expect(re.test("ChainlinkRelayerV1Factory")).toBe(false);
    expect(re.test("ChainlinkRelayerV1Helper")).toBe(false);
    expect(re.test("ChainlinkRelayerV1Mock")).toBe(false);
    // Real pairs (uppercase only) still match.
    expect(re.test("ChainlinkRelayerV1EURUSD")).toBe(true);
    expect(re.test("ChainlinkRelayerV1USDCUSD")).toBe(true);
  });

  it("CDP per-token patterns are anchored — no over-match", () => {
    const ap = INSTANCE_GROUPS.find((g) => g.base === "ActivePool")!.patterns[0]
      .regex;
    expect(ap.test("ActivePoolv300CHFm")).toBe(true);
    // Anchoring guards
    expect(ap.test("FooActivePoolv300CHFm")).toBe(false);
    expect(ap.test("ActivePoolv300CHFmExtra")).toBe(false);
    expect(ap.test("ActivePoolv300EVILm")).toBe(false); // unlisted token
    expect(ap.test("ActivePoolCHFm")).toBe(false); // missing v300
  });

  it("FXPriceFeed has both proxy and impl patterns with the right kinds", () => {
    const group = INSTANCE_GROUPS.find((g) => g.base === "FXPriceFeed")!;
    expect(group.patterns).toHaveLength(2);
    const kinds = group.patterns.map((p) => p.kind).sort();
    expect(kinds).toEqual(["impl", "proxy"]);
  });

  it("StabilityPool has both proxy and impl patterns with the right kinds", () => {
    const group = INSTANCE_GROUPS.find((g) => g.base === "StabilityPool")!;
    expect(group.patterns).toHaveLength(2);
    const kinds = group.patterns.map((p) => p.kind).sort();
    expect(kinds).toEqual(["impl", "proxy"]);
    const proxy = group.patterns.find((p) => p.kind === "proxy");
    const impl = group.patterns.find((p) => p.kind === "impl");
    expect(KIND_PRECEDENCE[proxy!.kind]).toBeLessThan(
      KIND_PRECEDENCE[impl!.kind],
    );
    // Sanity: proxy matches unversioned (user-facing), impl matches v300.
    expect(proxy!.regex.test("StabilityPoolCHFm")).toBe(true);
    expect(proxy!.regex.test("StabilityPoolv300CHFm")).toBe(false);
    expect(impl!.regex.test("StabilityPoolv300CHFm")).toBe(true);
    expect(impl!.regex.test("StabilityPoolCHFm")).toBe(false);
  });

  it("base names are unique across groups", () => {
    const bases = INSTANCE_GROUPS.map((g) => g.base);
    expect(new Set(bases).size).toBe(bases.length);
  });
});
