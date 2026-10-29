import { installPublicAnalytics } from "public_analytics"

// Approved GA-only CSP and sanitized event contract. Collection still requires
// explicit visitor consent on an eligible anonymous public document.
export const PUBLIC_ANALYTICS_ENABLED = true
const analytics = installPublicAnalytics({
  enabled: PUBLIC_ANALYTICS_ENABLED,
  id: "G-PPD2TWSZBW",
  origin: "https://trove.schweg.xyz",
  storageKey: "trove.analytics-consent.v1",
  turbo: true,
  page() {
    try { return JSON.parse(document.body.dataset.publicAnalytics || "null") }
    catch { return null }
  }
})
export function trackPublicShare(method) { return analytics.share(method) }
