import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const source = readFileSync(new URL("../../app/javascript/public_analytics.js", import.meta.url), "utf8");
const { installPublicAnalytics } = await import("data:text/javascript;base64," + Buffer.from(source).toString("base64"));
class Element extends EventTarget {
  constructor(tag) { super(); this.tagName = tag; this.children = []; this.attributes = new Map(); }
  append(...nodes) { this.children.push(...nodes); nodes.forEach(node => { node.parent = this; }); }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter(node => node !== this); }
  setAttribute(key, value) { this.attributes.set(key, value); }
  hasAttribute(key) { return this.attributes.has(key); }
}
function fixture(overrides = {}) {
  const win = new EventTarget();
  const doc = new EventTarget();
  const saved = new Map();
  let reloads = 0;
  const navigations = [];
  Object.assign(doc, { head: new Element("head"), body: new Element("body"),
    documentElement: new Element("html"), readyState: "complete", referrer: "https://www.google.com/search?q=private@example.test",
    createElement: tag => new Element(tag), querySelector: () => null });
  Object.assign(win, { document: doc, navigator: {}, location: { origin: "https://example.test", search: "", hash: "",
    reload: () => { reloads++; }, assign: url => navigations.push(url) },
    localStorage: { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value) } });
  let page = { path: "/public_shelf", title: "Public shelf", type: "public_shelf", group: "public" };
  const config = { enabled: true, id: "G-TEST123", storageKey: "consent", origin: win.location.origin,
    turbo: true, page: () => page, ...overrides };
  return { win, doc, saved, config, setPage: value => { page = value; },
    install: () => installPublicAnalytics(config, win), reloads: () => reloads, navigations };
}
function events(win, name) { return (win.dataLayer || []).filter(args => args[0] === "event" && (!name || args[1] === name)); }
test("release gate blocks tag, events and granting even with previously saved consent", () => {
  const f = fixture({ enabled: false }); f.saved.set("consent", "granted"); const api = f.install(); api.grant();
  assert.equal(f.doc.head.children.length, 0); assert.equal(f.win.gtag, undefined);
  assert.equal(api.share("native"), false);
  assert.match(f.doc.body.children[0].children[1].textContent, /off while setup/);
});
test("no tag or queued event before explicit consent; default ads remain denied", () => {
  const f = fixture(); const api = f.install(); assert.equal(f.win.dataLayer, undefined); api.grant();
  assert.equal(f.doc.head.children.length, 1); assert.equal(events(f.win, "page_view").length, 1);
  assert.equal(f.win.dataLayer[0][2].ad_personalization, "denied");
  assert.deepEqual(Array.from(f.win.dataLayer[1]), ["consent", "update", { analytics_storage: "granted" }]);
  const config = f.win.dataLayer.find(a => a[0] === "config")[2];
  assert.equal(config.send_page_view, false); assert.equal(config.allow_google_signals, false);
});
test("duplicate initial/Turbo load sends one pageview per body", () => {
  const f = fixture(); const api = f.install(); api.grant();
  f.doc.dispatchEvent(new Event("turbo:load")); f.doc.dispatchEvent(new Event("turbo:load"));
  assert.equal(events(f.win, "page_view").length, 1);
});
test("private route, wrong host, query, hash, preview and privacy preference fail closed", () => {
  for (const change of [f => f.setPage(null), f => { f.win.location.origin = "https://other.test"; },
    f => { f.win.location.search = "?email=private@example.test"; }, f => { f.win.location.hash = "#token=secret"; },
    f => f.doc.documentElement.setAttribute("data-turbo-preview", ""),
    f => { f.win.navigator.globalPrivacyControl = true; }, f => { f.win.navigator.doNotTrack = "1"; }]) {
    const f = fixture(); change(f); const api = f.install(); api.grant();
    assert.equal(f.doc.head.children.length, 0); assert.equal(events(f.win).length, 0);
  }
});
test("metadata contains static aggregate page and origin-only approved referrer", () => {
  const f = fixture(); f.install().grant(); const data = events(f.win, "page_view")[0][2];
  assert.equal(data.page_location, "https://example.test/public_shelf");
  assert.equal(data.page_referrer, "https://www.google.com/");
  assert.doesNotMatch(JSON.stringify(f.win.dataLayer), /private@|search\?|token=|viewer|username/);
});
test("unknown referrer is omitted", () => {
  const f = fixture(); f.doc.referrer = "https://private-host.test/account?email=secret";
  f.install().grant(); assert.equal(events(f.win, "page_view")[0][2].page_referrer, "");
});
test("only supported successful share methods on eligible shelf are emitted", () => {
  const f = fixture(); const api = f.install(); api.grant();
  assert.equal(api.share("native"), true); assert.equal(api.share("copy_link"), true);
  assert.equal(api.share("private@example.test"), false);
  f.setPage({ path: "/", title: "Home", type: "home", group: "public" });
  assert.equal(api.share("native"), false); assert.equal(events(f.win, "share").length, 2);
});
test("revocation disables collection and reloads to destroy Google listeners", () => {
  const f = fixture(); const api = f.install(); api.grant(); api.deny();
  assert.equal(f.saved.get("consent"), "denied"); assert.equal(f.win["ga-disable-G-TEST123"], true);
  assert.equal(f.reloads(), 1); assert.equal(api.share("native"), false);
});
test("storage revocation in another tab also stops collection", () => {
  const f = fixture(); const api = f.install(); api.grant();
  const event = new Event("storage"); Object.assign(event, { key: "consent", newValue: "denied" });
  f.win.dispatchEvent(event); assert.equal(f.reloads(), 1); assert.equal(api.share("native"), false);
});
test("Turbo visit after tag startup is suspended and becomes a full document navigation", () => {
  const f = fixture(); const api = f.install(); api.grant();
  assert.equal(f.doc.documentElement.attributes.get("data-turbo"), "false");
  const event = new Event("turbo:before-visit", { cancelable: true }); event.detail = { url: "https://example.test/login" };
  f.doc.dispatchEvent(event); assert.equal(event.defaultPrevented, true);
  assert.deepEqual(f.navigations, ["https://example.test/login"]); assert.equal(api.share("native"), false);
});
test("programmatic Turbo render cannot keep a loaded tag alive in a private body", () => {
  const f = fixture(); f.install().grant();
  const event = new Event("turbo:before-render", { cancelable: true }); f.doc.dispatchEvent(event);
  assert.equal(event.defaultPrevented, true); assert.equal(f.reloads(), 1);
});
test("blocked storage permits only document-scoped explicit consent", () => {
  const f = fixture(); f.win.localStorage = { getItem() { throw Error(); }, setItem() { throw Error(); } };
  const api = f.install(); assert.equal(f.doc.head.children.length, 0); api.grant();
  assert.equal(events(f.win, "page_view").length, 1);
});
