// Shared schema v2: dated, explicitly enabled artwork; no inferred annual recurrence.
export function currentSeason(config, now = Date.now()) {
  if (config?.schemaVersion !== 2) return null
  return config.seasons?.find(season => (!config.activeSeason || season.id === config.activeSeason) && season.enabled && season.asset &&
    (!season.window || (now >= Date.parse(season.window.from) && now < Date.parse(season.window.until)))) || null
}
export const SEASONAL_KEYS = {
  theme: "seasonal-theme:v1", motion: "seasonal-motion:v1",
  prompt: id => `seasonal-prompt:v1:${id}`,
  active: id => `trove-seasonal-session:v2:${id}`
}
