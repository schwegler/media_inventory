// First-party consent controller. The production adapter must remain disabled
// until its CSP and GA automatic-measurement settings have been reviewed.
export function installPublicAnalytics(config, win = window) {
  const doc = win.document;
  let started = false;
  let suspended = false;
  let grantForDocument = false;
  let panel;
  const countedBodies = new WeakSet();
  const owned = new Map([
    ["tacobout.online", "tacobout"],
    ["trove.schweg.xyz", "trove"],
    ["schweg.xyz", "schweg"],
  ]);
  const referrers = new Set([
    ...owned.keys(), "www.google.com", "www.bing.com", "duckduckgo.com",
    "bsky.app", "mastodon.social", "t.co", "www.reddit.com", "www.youtube.com",
  ]);
  function preference() {
    try { return win.localStorage.getItem(config.storageKey); }
    catch { return null; }
  }
  function context() {
    if (win.navigator?.globalPrivacyControl === true || win.navigator?.doNotTrack === "1" ||
        win.location.origin !== config.origin || win.location.search ||
        win.location.hash || doc.documentElement.hasAttribute("data-turbo-preview")) return null;
    const page = config.page();
    if (!page || !/^\/[a-z0-9_/-]*$/.test(page.path) ||
        !/^[a-z_]+$/.test(page.type) || !/^[a-z_]+$/.test(page.group)) return null;
    return page;
  }
  function allowed() {
    return config.enabled === true && !suspended && context() &&
      (grantForDocument || preference() === "granted");
  }
  function metadata() {
    const page = context();
    let referrer = "";
    try {
      const url = new URL(doc.referrer);
      if (url.protocol === "https:" && referrers.has(url.hostname)) referrer = url.origin + "/";
    } catch { /* Empty and unapproved referrers stay empty. */ }
    return { page_location: config.origin + page.path, page_title: page.title,
      page_referrer: referrer, content_type: page.type, content_group: page.group };
  }
  function command() { win.dataLayer.push(arguments); }
  function emit(name, extra = {}) {
    if (!started || !allowed()) return false;
    command("event", name, { ...metadata(), ...extra, send_to: config.id });
    return true;
  }
  function pageview() {
    if (countedBodies.has(doc.body) || !allowed()) return;
    countedBodies.add(doc.body);
    emit("page_view");
  }
  function start() {
    if (!allowed()) return;
    if (!started) {
      started = true;
      win.dataLayer = win.dataLayer || [];
      win.gtag = command;
      command("consent", "default", { analytics_storage: "denied", ad_storage: "denied",
        ad_user_data: "denied", ad_personalization: "denied" });
      command("consent", "update", { analytics_storage: "granted" });
      command("js", new Date());
      command("config", config.id, { ...metadata(), send_page_view: false,
        allow_google_signals: false, allow_ad_personalization_signals: false });
      const script = doc.createElement("script");
      script.async = true;
      script.src = "https://www.googletagmanager.com/gtag/js?id=" + config.id;
      // Do not copy a Rails nonce onto third-party code. The proposed explicit
      // origin allowlist, once approved, is the only way this script may load.
      doc.head.append(script);
      // An opted-in public document uses full navigations. This prevents Google
      // listeners surviving Turbo into authentication or private account bodies.
      if (config.turbo) doc.documentElement.setAttribute("data-turbo", "false");
    }
    pageview();
  }
  function grant() {
    if (config.enabled !== true || !context()) return;
    suspended = false;
    grantForDocument = true;
    try { win.localStorage.setItem(config.storageKey, "granted"); } catch { /* Document-only consent. */ }
    start();
    render();
  }
  function deny() {
    grantForDocument = false;
    try { win.localStorage.setItem(config.storageKey, "denied"); } catch { /* No persistence available. */ }
    suspended = true;
    if (started) {
      win["ga-disable-" + config.id] = true;
      command("consent", "update", { analytics_storage: "denied", ad_storage: "denied",
        ad_user_data: "denied", ad_personalization: "denied" });
      win.location.reload(); // Destroy already-installed third-party listeners.
    } else render();
  }
  function render() {
    panel?.remove();
    panel = null;
    if (!context()) return;
    panel = doc.createElement("details");
    panel.className = "analytics-preferences";
    const summary = doc.createElement("summary");
    summary.textContent = "Analytics preferences";
    const text = doc.createElement("p");
    text.textContent = config.enabled !== true
      ? "Analytics is off while setup is under review. No Google Analytics tag is loaded."
      : allowed()
        ? "Optional Google Analytics is on for this public page. You can turn it off at any time."
        : "Optional Google Analytics is off. Allow it to measure visits to public pages. Your choice is saved only in this browser. Advertising personalization stays off.";
    const allow = doc.createElement("button");
    allow.type = "button";
    allow.textContent = "Allow analytics";
    allow.disabled = config.enabled !== true || !!allowed();
    allow.addEventListener("click", grant);
    const decline = doc.createElement("button");
    decline.type = "button";
    decline.textContent = "Keep analytics off";
    decline.addEventListener("click", deny);
    panel.append(summary, text, allow, decline);
    (doc.querySelector("footer") || doc.body).append(panel);
  }
  function mount() { render(); start(); }
  if (doc.readyState === "loading") doc.addEventListener("DOMContentLoaded", mount, { once: true });
  else mount();
  doc.addEventListener("turbo:load", mount);
  win.addEventListener("storage", event => {
    if (event.key === config.storageKey && event.newValue !== "granted") deny();
  });
  doc.addEventListener("turbo:before-cache", () => { panel?.remove(); panel = null; });
  doc.addEventListener("turbo:before-visit", event => {
    if (!started) return;
    event.preventDefault();
    suspended = true;
    win.location.assign(event.detail.url);
  });
  doc.addEventListener("turbo:before-render", event => {
    if (!started) return;
    event.preventDefault();
    suspended = true;
    win.location.reload();
  });
  doc.addEventListener("click", event => {
    if (event.defaultPrevented || event.button > 0) return;
    const link = event.target.closest?.("a[href]");
    if (!link) return;
    let url;
    try { url = new URL(link.href); } catch { return; }
    const destination = url.protocol === "https:" && owned.get(url.hostname);
    if (destination && url.origin !== config.origin) emit("owned_site_click", { destination_site: destination });
  });
  return {
    grant, deny,
    share(method) {
      if (context()?.type !== "public_shelf" || !["native", "copy_link"].includes(method)) return false;
      return emit("share", { method });
    },
  };
}
