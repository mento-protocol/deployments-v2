import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["scripts/**/*.test.ts"],
    // Most tests are pure-function unit tests; one test exercises the
    // generator's CLI. Keep them under one second each to avoid CI drag.
    testTimeout: 5000,
  },
});
