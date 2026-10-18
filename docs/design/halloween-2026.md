# Halloween 2026

Account accent, profile accent/header, and shelf palettes remain independent opt-in preferences. Existing choices and uploaded profile banners are preserved. Halloween palettes remain available after the promotion ends.

The invitation campaign is **[2026-10-18 00:00:00 UTC, 2026-11-01 00:00:00 UTC)**. Both server rendering and client activation enforce this single fixed interval; no future-year recurrence. A single deadline timer removes an invitation from an already open page. There is no polling or network request on activation.

The invitation previews dark + Halloween on the current page only. Undo restores the exact previous `data-theme` and `data-accent` attributes (including missing attributes); it never changes saved account/profile/shelf preferences. Navigation and Turbo snapshot caching clear the preview. Signed-in readers can save Halloween explicitly in Appearance. Dismissal is stored under `trove-halloween-2026` on this browser; blocked storage falls back to page-only dismissal. No tracking identifiers or account data are stored.

The invitation reserves normal document flow under navigation, so its restrained floating decoration never covers controls. Native buttons support touch and keyboard, with a 44px minimum target. An alert announces activation, focus moves to Undo, and no short timeout removes that action. OS reduced motion and the account's reduced effects preference disable decoration movement. Movement otherwise stops after three cycles.

Use the existing detailed Facet PNG as reference for the requested bat-costume asset; do not substitute a simplified SVG. Decorative character images have empty alt text, while the action button names its purpose.

Social image composition proposals are review-only. Existing renderer geometry stays unchanged until a design is approved. Palette addition uses the same colors in shelf UI and both canvas formats.
