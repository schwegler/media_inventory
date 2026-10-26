# Unified shelves

## Inventory and boundaries

The public `/@username/shelf` route owns seven FavoriteShelf categories (Overall, Movies, TV shows, Albums, Comics, Books, Games) and named ShelfCollection records. Category favorites retain five picks. Collections retain their titles, descriptions, random stable slugs, creation order, JSON item order, saved theme/layout/texture/companion settings and independent picks. No Lists model or route is introduced.

Profile Collection/Backlog is LibraryItem data. In Progress is tracking data from existing services. Neither becomes shelf selections. Existing quick-progress widgets, TV/comic/game privacy behavior and personal reviews remain outside this change. Public shelf records are public selections today; there is no collection visibility field. Publishing a preview creates an OG image, not a visibility change. This branch adds no visibility setting or data migration. Future private/unlisted support must gate show, overview, reverse lookup and OG metadata together before exposing such a control.

The existing picker searches six catalog types and imports signed external choices without creating a LibraryItem. Public payload remains only id/type/title/cover/url. Shared media cards with ratings and library state are deliberately not reused.

## Permission matrix

| Capability | Owner | Signed-in visitor | Logged-out visitor |
|---|---|---|---|
| View public selections and metadata | Yes | Yes | Yes |
| Edit title, picks, order, display count, mix, appearance | Yes | No; server returns 403 | No; sign-in redirect |
| Import catalog title | Existing signed-in catalog authorization | Existing signed-in catalog authorization; cannot write another shelf | Sign-in required |
| Copy/native share/download public shelf | Yes, saved selections | Yes | Yes |
| Publish owner's OG image | Yes | No | No |
| See private reviews, library state or game sessions in shelf data | No | No | No |
| Owner visitor preview | Read-only presentation | Read-only | Read-only |

## Visual concept and implementation system

Concept: `unified-shelves-concept.png` (generated UI concept, not a production asset). Reference Library image `libfile_fca8841bee508191a4cadf50d266927f` was materialized with the current Library helper; PNG bytes and pixels inspected. Its ordered collection and compact controls inform the hierarchy, not its branding, content or social features.

Existing shelf palette tokens and approved artwork remain authoritative, including historical seasonal layouts. Preserve saved presentation over visitor query preferences. Georgia editorial headings; existing application control font; 44px minimum action geometry, 6px action radius, thin dividers, open grid. Desktop six columns, medium four, mobile two. Covers contain rather than crop artwork. Item position, media type and linked title remain visible with missing covers. Shared partial families: toolbar, header, media item, empty state, collection card and settings.

Owner detail: title/context/count/attribution, Add / Save / Copy / Share, collapsed settings, full ordered grid, explicit earlier/later/remove buttons. Public detail shares the header and grid with read-only actions. Overview shows 1–12 configured covers and the full count; changing preview length never deletes selections. Empty shelves explain the next action. Image customization/download/alt-text/publish remains available under a secondary disclosure. Images explicitly feature first five selections and state larger totals.

Intentional concept deviations: keep current navigation, all saved palette colors and existing image layouts; use actual catalog fixtures rather than generated cover art; no invented About section, owner avatar or redundant full-shelf overview on detail. No new mascots.

## Preservation checklist

- [x] All seven favorite shelves and five-item validation unchanged.
- [x] Existing custom collection IDs, slugs, URLs and stored picks preserved.
- [x] Flexible count separated from bounded overview and five-cover social images.
- [x] Changing allowed mix retains existing selections; only new additions are restricted.
- [x] Cross-media local/external picker, signed imports, no implied library ownership.
- [x] Keyboard earlier/later, dirty-navigation guard, picker focus return, repeated-save guard retained.
- [x] Stale editor snapshots return conflict under owner row lock.
- [x] Owner authorization enforced before all shelf mutations.
- [x] Narrow public payload; no personal ratings/progress/session state added.
- [x] Profile and In Progress services untouched.
- [x] Appearance presets, legacy reading layout, export/alt text and explicit OG publishing retained.
- [ ] Browser verification and exact-head CI recorded below before handoff.

## Data and reverse lookup

Reversible additive migration adds allowed_media_types (empty means all six) and preview_length (default five). No stored picks are rewritten. Existing JSON identity `{type,id}` is canonical for later title-page reverse lookup; scope to public selection records and compare both type and ID. Do not derive inclusion from LibraryItem or private progress. A query service/index should be added with the separately scoped entity-page feature, rather than exposing a broad search endpoint here.

## Discovery integration contract

`PublicShelfMembership.call(item, limit: 6)` returns at most 12 entries with `title`, `creator: {name, username}`, stable relative `url`, stored selection `count`, and up to five `covers: [{title, type, cover}]`. It mirrors homepage discoverability: confirmed user, nonempty handle, published preview attachment, favorites only. Named collections remain accessible via existing direct public URLs but are excluded from discovery, preserving current publication intent. Membership examines only the 500 most recently updated eligible favorite shelves through a bounded ID subquery. Older matching shelves can be absent; consumers should say “From recently updated published shelves,” never “popular.” SQLite and PostgreSQL compare type and ID as exact text, supporting persisted numeric/string IDs consistently. No viewer data is included. No private/unlisted feature is introduced.


## Review checkpoint (paused by parent)

Implementation is saved for design review, not declared complete. Verified locally on Ruby 3.4.12 / Rails 8.1.4: 31 request/service examples passed; 93 JS checks passed (subsequent shelf-only rerun: 22 passed); Brakeman zero warnings; additive migration down/up succeeded against a disposable SQLite database. IAB inspected owner/public desktop, mobile, saved Gallery presentation and 640px equivalent 200% reflow. Latest browser pass: 7 examples, 0 failures, including twelve mixed titles, keyboard reorder/save, settings, picker focus, owner/visitor, light/dark, mobile/reflow and the existing export flows. Log: `/tmp/shelves-browser-delivery.log`. Full repository lint is queued in the same process; check `/tmp/shelves-all-lint.log`. Exact-head CI and final visual sign-off remain pending.

Concept/render comparison inspected: compact serif title hierarchy; shared action geometry; six-column desktop and two-column mobile grid; visible item type/order/title; full uncropped covers and readable missing-cover fallback; wrapped description/controls at 390px. Deliberate differences preserve Trove's existing navigation and saved palettes instead of replacing them with generated styling. Latest production screenshots and concept were inspected with view_image; no final 10/10 fidelity claim is made at this checkpoint.

Shared dependency: media-detail task cherry-picked b0df5b69 as 491c4b75 and 9beea6f3 as 00e3cc14. Coordinate landing/rebase so those identical service changes are not implemented twice. No unrelated review/search task files changed. Unrelated `.Jules/palette.md` working change was left out of shelf commits.
