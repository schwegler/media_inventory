## 2026-10-18 - Dynamic Bulk Action Button ARIA Synchronization
**Learning:** Bulk action buttons whose visible text toggles dynamically (e.g. "Mark all read" vs "Undo all read") require explicit `aria-label` attributes in both server-side rendered templates and client-side Stimulus controllers to give screen reader users unambiguous context on what action will occur.
**Action:** Always pair server-side `aria: { label: ... }` on toggling action buttons with client-side `button.setAttribute('aria-label', ...)` updates in Stimulus controllers.

## 2026-03-31 - Favorite Shelf Search Modal Focus & ARIA Association
**Learning:** Native `<dialog>` elements must be associated with their visible modal heading via `aria-labelledby` to give screen reader users clear context upon activation, and opening triggers should be captured so focus can be restored to `this.opener` on the native `close` event.
**Action:** Ensure native `<dialog>` containers include `aria-labelledby` matching the heading `id`, and add a `close` event listener to restore focus to `this.opener`.

## 2026-04-14 - Dropdown Menu Selection Auto-Closure & Turbo Cache Cleanup
**Learning:** Dropdown menus using Stimulus controllers must listen for clicks on internal menu items (`[role="menuitem"]`, `.dropdown-item`, links, or buttons) to hide immediately upon selection and listen for `turbo:before-cache` to avoid caching open dropdown states.
**Action:** Attach a click listener to `menuTarget` in `connect()` that calls `this.hide()` when clicking menu items, and clean up open states on `turbo:before-cache`.
