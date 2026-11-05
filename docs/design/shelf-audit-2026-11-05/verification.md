# Verification record

Baseline: `8b810e3c9f526a173f91c9e0fb7c9296ba418144` (`master`). Isolated branch: `fix/shelf-share-navigation`. No merge or deployment.

## Executed locally

- Ruby 3.4.12 built into a task-local toolchain; current locked gems installed in `/workspace/bundle34`. Dedicated disposable SQLite URLs were explicitly set to `/workspace/shelf-audit/isolated-test.sqlite3` and `isolated-browser.sqlite3`; no inherited development/production database, seed or migration was used.
- `rails db:schema:load` and `rails dartsass:build`: passed against disposable test configuration.
- RSpec requests: `favorite_shelves_spec`, `shelf_workspace_spec`, `flexible_shelves_spec`, `media_public_shelves_spec`: **43 examples, 0 failures**. Includes anonymous, owner and signed-in non-owner visibility/authorization and persistence boundaries.
- Chromium system suite: `shelf_appearance_journey_system_spec`, `shelf_customization_system_spec`, `shelf_overview_theme_system_spec`, `shelf_workspace_system_spec`: **13 examples, 0 failures**. Includes new sharing section keyboard/focus, repeated reopen, cross-page Back/Forward, clipboard failure/manual selection, native cancel, owner appearance undo/save, independent named presentation, exports/mascots and responsive reflow.
- Node aggregate `node --test spec/javascript/*.test.cjs spec/javascript/*.test.mjs`: **136 tests passed**. New coverage: immediate native invocation, repeat-click suppression, unsupported native clipboard feedback, native cancel/reject/manual recovery, dirty/saving guard, Turbo restoration metadata retention and detached-page completion.
- RuboCop on the three changed Ruby spec files: **3 inspected, no offenses**. Public-email guard and `git diff --check`: passed.
- Inspected actual supplied screenshot pixels. Live anonymous Chromium reproduced both baseline Share behaviors at the exact supplied URL: header fallback copied profile; toolbar opened details but left hash empty/scroll at 0, with sharing section at y=2239.6. No captured page errors. Default overview at 390px had no horizontal overflow. Internal live screenshots contain real content and are not published as artifacts.
- Actual local synthetic screenshots inspected: desktop/mobile share feedback and consistent toolbar; mobile sharing destination; existing theme/appearance checks. Physical devices and non-Chromium engines not tested.
- Isolated HTML prototype tested in Chromium at 1280px, 768px, 390px and 320px: create/empty state, local search/add, missing-art item, Escape/focus restoration, undo, appearance change/save, simulated failure/retry, publication state, visitor preview, sharing dialog, Back. No captured JavaScript errors; checked 390px/320px paths had no horizontal overflow. Desktop and mobile design pixels inspected. Export/native/publication outcomes are explicitly simulated; no real social post or production write.

## Development failures resolved

An initial RSpec command named a nonexistent `shelves_spec.rb`; corrected to the actual request suite. Old label assertions were updated for the intentional explicit destinations. Capybara path matching excludes fragments by default, so the hash assertion now reads `location.hash`. A real cross-page Back failure exposed lost Turbo history metadata; preserving history state fixed it. A trial Turbo.visit approach regressed existing appearance history and was removed. The final suite retains all existing appearance behavior. One spec line-length offense was corrected. Earlier failing outputs are not the final result.

## CI and remaining limits

The draft PR's exact remote head and settled CI results are recorded in the PR description and handoff. CI is authoritative for its PostgreSQL/SQLite aggregate, browser, security, lint and image jobs; focused local passes do not imply those checks passed. No PostgreSQL suite, full Rails aggregate, actual Safari/iOS share sheet, physical phone, production owner writes, external social crawler cache refresh or load benchmark was run locally.

The audit distinguishes source risks and hypotheses from observed defects. It is an expert walkthrough, not participant usability evidence. The complete redesign, atomic save API, label/entry fixes outside the immediate report, performance changes and optional direct shelf-link action are proposals only. Existing user content, routes, profile-sharing intent, valid presentation values and approved mascot assets are preserved by the implementation.
