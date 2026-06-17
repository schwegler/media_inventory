## 2026-06-17 - [Interactive Thumbnail Accessibility]
**Learning:** In Hotwire/Stimulus apps with custom-built interactive galleries (like our thumbnail fetcher), adding only `click` listeners on `div` elements excludes keyboard users.
**Action:** Always include `tabindex="0"`, `role="button"`, and a `keydown` listener (handling Enter/Space) for any custom interactive element that isn't a native `<button>` or `<a>`.
