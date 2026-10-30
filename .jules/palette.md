## 2026-10-18 - Dynamic Bulk Action Button ARIA Synchronization
**Learning:** Bulk action buttons whose visible text toggles dynamically (e.g. "Mark all read" vs "Undo all read") require explicit `aria-label` attributes in both server-side rendered templates and client-side Stimulus controllers to give screen reader users unambiguous context on what action will occur.
**Action:** Always pair server-side `aria: { label: ... }` on toggling action buttons with client-side `button.setAttribute('aria-label', ...)` updates in Stimulus controllers.

## 2026-03-31 - Favorite Shelf Search Modal Focus & ARIA Association
**Learning:** Native `<dialog>` elements must be associated with their visible modal heading via `aria-labelledby` to give screen reader users clear context upon activation, and opening triggers should be captured so focus can be restored to `this.opener` on the native `close` event.
**Action:** Ensure native `<dialog>` containers include `aria-labelledby` matching the heading `id`, and add a `close` event listener to restore focus to `this.opener`.

## 2026-04-14 - Dropdown Menu Selection Auto-Closure & Turbo Cache Cleanup
**Learning:** Dropdown menus using Stimulus controllers must listen for clicks on internal menu items (`[role="menuitem"]`, `.dropdown-item`, links, or buttons) to hide immediately upon selection and listen for `turbo:before-cache` to avoid caching open dropdown states.
**Action:** Attach a click listener to `menuTarget` in `connect()` that calls `this.hide()` when clicking menu items, and clean up open states on `turbo:before-cache`.

## 2026-10-24 - Dynamic Consumed Date Row ARIA & Focus Management
**Learning:** Checkboxes toggling expandable date fields (such as "Consumed" in modal log forms) must link to the toggled element via `aria-controls`, maintain `aria-expanded` and `aria-hidden` states, and shift focus to the expanded input when toggled on by user interaction.
**Action:** When creating toggle Stimulus controllers for form sections, set `aria-controls`, update `aria-expanded` and `aria-hidden`, and focus the first input inside the expanded row when `event` is present.

## 2026-10-29 - Expandable Tab Island Toggle ARIA Synchronization
**Learning:** Action buttons that toggle tabbed UI sections between compact tabbed views and full expanded list views must maintain `aria-expanded` and `aria-controls` attributes on the toggle button across server-side rendering and client-side Stimulus state transitions.
**Action:** Pair initial server-side `aria-expanded` and `aria-controls` attributes with a dedicated update helper method in Stimulus controllers that synchronizes `aria-expanded` on `connect()`, `expand()`, `select()`, and `reveal()`.

## 2026-11-05 - Focus Preservation on Disabled Stepping Controls
**Learning:** Stepping buttons in paginated or tabbed navigation (such as TV show season controls) that become disabled (`disabled = true`) when reaching boundary limits automatically drop browser focus to `document.body`. This causes screen reader and keyboard users to lose their place on the page.
**Action:** When updating button disabled states in Stimulus controllers, check if `document.activeElement` is disabled and immediately shift focus to an active fallback control (`previousTarget`, `nextTarget`, or selector dropdown).
