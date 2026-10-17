## 2026-03-31 - Favorite Shelf Search Modal Focus & ARIA Association
**Learning:** Native `<dialog>` elements must be associated with their visible modal heading via `aria-labelledby` to give screen reader users clear context upon activation, and opening triggers should be captured so focus can be restored to `this.opener` on the native `close` event.
**Action:** Ensure native `<dialog>` containers include `aria-labelledby` matching the heading `id`, and add a `close` event listener to restore focus to `this.opener`.
