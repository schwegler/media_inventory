# Halloween 2026

Account accent, profile accent/header, and shelf palettes remain independent opt-in preferences. Existing choices and uploaded profile banners are preserved. Halloween palettes remain available after the promotion ends.

The invitation campaign is **[2026-10-18 00:00:00 UTC, 2026-11-01 00:00:00 UTC)**. Both server rendering and client activation enforce this single fixed interval; no future-year recurrence. A single deadline timer removes an invitation from an already open page. There is no polling or network request on activation.

The invitation previews dark + Halloween for the current browser session. Undo restores the exact previous `data-theme` and `data-accent` attributes (including missing attributes); it never changes saved account/profile/shelf preferences. The session override survives navigation; Turbo snapshots retain the original appearance and reapply only after checking the explicit session choice. A viewer or saved-preference change clears the override. Blocked session storage falls back to the current page. Signed-in readers can save Halloween explicitly in Appearance. Dismissal is stored under `trove-halloween-2026` on this browser; blocked storage falls back to page-only dismissal. Session storage holds only the previous theme attributes, viewer ID, and appearance preference signature to prevent carrying an override into another account; no analytics or network calls use this state.

The invitation reserves normal document flow under navigation, so its restrained floating decoration never covers controls. Native buttons support touch and keyboard, with a 44px minimum target. An alert announces activation, focus moves to Undo, and no short timeout removes that action. OS reduced motion and the account's reduced effects preference disable decoration movement. Movement otherwise stops after three cycles.

The detailed Facet-in-bat-costume PNG was generated with the built-in imagegen tool using `public/brand/facet_pose_03_crate_digger.png` as the identity reference. The production PNG is `app/assets/images/brand/facet_bat_costume_2026.png`, dimensioned at 56×72 CSS pixels and optimized to a 192px high transparent PNG. The full-resolution source is retained in `docs/design/assets/facet-bat-2026-source.png`. Decorative character images have empty alt text, while the action button names its purpose.

Social image composition proposals are review-only. Existing renderer geometry stays unchanged until a design is approved. Palette addition uses the same colors in shelf UI and both canvas formats.

Asset prompt: “Preserve the violet faceted crystal head, golden round glasses, purple outfit and detailed outlined PNG style. Dress the same Facet character in a dark plum scalloped bat-wing cape with soft bat ears, full body, friendly expression, genuine transparent background, no text or watermark.”

## Verification evidence

- Nonbrowser suite: 900 examples, zero failures, nine existing pending examples.
- JavaScript suite: 19 tests passed, including the fixed campaign boundary, activation without saved preference mutation, exact Undo restoration, dismissal, and deadline reset.
- Existing appearance/shelf browser regressions: two examples passed. Halloween keyboard/browser regression: one example passed on an isolated temporary database.
- Responsive real-page checks: 1440px desktop and 390px mobile, keyboard activation/Undo focus, alert, reduced motion, exact restoration, persistent dismissal, public profile and shelf overflow.
- RuboCop: zero offenses; assets build succeeded; Brakeman: zero security warnings; current bundler-audit: no vulnerabilities; public email guard passed.
- Existing development console CSP violations block Google Analytics; no seasonal controller errors were found.

Screenshots are retained in `docs/screenshots/halloween/`: invitation, applied desktop/mobile theme, profile decoration, shelf palette, and three social comparison sheets. These use a local illustrative account, never production ownership/history.
