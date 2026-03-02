import fs from "fs";
import path from "path";
import { revert } from "../../test-ts/anvil";

const FIXTURE_PATH = path.resolve(__dirname, "../../.treb/priv/test-fixture.json");

async function main() {
  if (!fs.existsSync(FIXTURE_PATH)) {
    console.log("post-test: no fixture file found, nothing to revert.");
    return;
  }

  const fixture = JSON.parse(fs.readFileSync(FIXTURE_PATH, "utf8"));

  console.log("post-test: reverting snapshot...");
  await revert(fixture.snapshotId);

  console.log("post-test: deleting fixture file...");
  fs.unlinkSync(FIXTURE_PATH);

  console.log("post-test: done.");
}

main().catch((err) => {
  console.error("post-test failed:", err);
  process.exit(1);
});
