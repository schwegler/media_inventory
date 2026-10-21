import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
const source = readFileSync(new URL("../../app/javascript/controllers/link_share_controller.js", import.meta.url), "utf8")
  .replace(/^import .*$/gm, "").replace("export default class", "class ShareController") + "\nglobalThis.ShareController = ShareController;";
function fixture(navigator) {
  const events = [];
  const sandbox = { Controller: class {}, navigator, trackPublicShare: method => events.push(method), setTimeout, clearTimeout };
  vm.runInNewContext(source, sandbox);
  const controller = new sandbox.ShareController();
  Object.assign(controller, { titleValue: "Sensitive title excluded from analytics", urlValue: "https://trove.schweg.xyz/@private/shelf", showStatus() {} });
  return { controller, events };
}
test("completed native share emits only native method", async () => {
  const f = fixture({ share: async () => {} }); await f.controller.share(); assert.deepEqual(f.events, ["native"]);
});
test("cancelled native share does not emit or copy", async () => {
  const f = fixture({ share: async () => { throw Object.assign(Error(), { name: "AbortError" }); } });
  await f.controller.share(); assert.deepEqual(f.events, []);
});
test("failed native share followed by successful clipboard emits only copy_link", async () => {
  const f = fixture({ share: async () => { throw Error(); }, clipboard: { writeText: async () => {} } });
  await f.controller.share(); assert.deepEqual(f.events, ["copy_link"]);
});
test("clipboard failure and manual-copy fallback do not emit success", async () => {
  const f = fixture({ clipboard: { writeText: async () => { throw Error(); } } });
  await f.controller.copy(); assert.deepEqual(f.events, []);
});
