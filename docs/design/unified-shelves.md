# Unified shelves

## Architecture and preserved behavior

The existing `/@username/shelf` route serves seven FavoriteShelf categories and named ShelfCollection records. There is no Lists model, parallel subsystem or navigation redesign. Favorites remain Overall, Movies, TV shows, Albums, Comics, Books and Games, with five picks each. Named shelves retain their IDs, random stable slugs, URLs, titles, descriptions, JSON item order, creation order and saved theme/layout/texture/companion settings.

Custom shelves support **1,000 stored titles**. Existing oversized records retain their stored capacity and remain editable; additions cannot increase that capacity. No operation truncates picks. Overview length is independently configurable from 1–12 covers. Detail pages display every resolved title; social images feature the first five covers and explicitly report larger totals. Changing the allowed media mix restricts future additions while preserving existing selections. Displayed media metadata describes actual selections, rather than implying that retained titles were removed by a new restriction.

Profile Collection/Backlog remains LibraryItem data; In Progress remains tracking-service data. Their widgets, quick progress, TV/comic/game privacy rules and personal reviews are untouched. The six-type catalog picker and signed external imports remain available without implying library ownership or creating a LibraryItem. Public media cards expose only id/type/title/cover/URL, never private ratings, progress or sessions.

Shared partials provide the toolbar, header, media item, empty state, collection card, settings and theme controls. Owners have Add / Save / Copy / Share, replace/remove, keyboard earlier/later controls, a compact secondary-action menu and settings. Visitors have the same title/media hierarchy with read-only actions. Empty, missing-cover and long-title states use actual text. Dirty navigation protection, picker focus return, focus after removing the final title, double-save prevention and stale response protection are retained. Server writes are owner-scoped and serialized under the owner row lock. Optimistic edit versions are separate from existing favorite OG fingerprints, preserving published favorite-image identity.

## Permission matrix

| Capability | Owner | Signed-in visitor | Logged-out visitor |
|---|---|---|---|
| Open existing public shelf URL | Yes | Yes | Yes |
| Edit selections, order, context, display count, mix, appearance | Yes | No; server 403 | No; sign-in redirect |
| Import signed catalog title | Existing signed-in authorization | Existing catalog authorization, without access to another shelf | Sign-in required |
| Copy/native share/download saved public selections | Yes | Yes | Yes |
| Publish owner's preview | Yes | No | No |
| Read private library state, reviews or sessions through shelf payload | No | No | No |
| Owner's visitor-preview mode | Read-only UI | Read-only | Read-only |

There is no private/unlisted collection field today. This work adds no visibility control, changes no direct-link access rule and runs no production migration. Future visibility support must gate show, profile widgets, discovery, previews and metadata together. Publishing an OG image is distinct from changing link access.

## Named shelf discovery and integration

`PublicShelfMembership.call(item, limit: 6)` returns at most 12 entries with `title`, `creator: {name, username}`, stable relative `url`, stored selection `count`, and up to five `covers: [{title, type, cover}]`. SQLite and PostgreSQL match both media type and ID as exact text, supporting numeric/string persisted IDs consistently.

Favorites retain the homepage gate: confirmed account, nonempty handle and an existing published preview. Named collections additionally require a preview specifically for `collection:slug` with the **current exact signature**. A generic account preview does not publish a named shelf. Changed titles, picks or other fingerprinted settings do not enter discovery through an old preview. The owner-facing publication copy explains this eligibility and the need to republish after editing. No private library source participates.

A metadata-only Arel UNION bounds the **combined favorite + named candidate window to 500** before inspecting JSON picks. Current-publication filtering then excludes unpublished or stale named candidates. A second bound selects the newest 500 preview attachment IDs across matched named curators before examining blob metadata. Older otherwise eligible matching shelves or previews can be absent, and unpublished/stale candidates can reduce the returned set. Consumers therefore label the section “From recently updated published shelves” and disclose “Older matching shelves may be missing.” This is partial recency-based discovery, with no popularity metric or exhaustive-list claim.

Publication metadata is fetched as one narrow DISTINCT query of exact user/category/signature tuples, at most one tuple per named candidate. It does not instantiate every preview attachment/blob a curator owns. Six same-type favorite shelves measured **five SQL queries**. Preview artwork is batched by media type. No public mutation endpoint is added.

Shared patches were cherry-picked into media-detail draft #685: original b0df5b69, 9beea6f3, 8579aafd and 69c2e690, plus final bound correction ea424b07. The shelf branch was subsequently rebased onto master 227624c5. Preferred integration order: land the shelf change first only after approval; rebase the media-detail draft onto it and drop identical shared patches. Both PRs remain draft and must pass checks on their own final heads.

## Migration preservation

The reversible additive migration creates `allowed_media_types` (default `[]`, meaning all six types) and `preview_length` (default `5`). It rewrites no picks or existing attributes. The isolated verification script exercises existing 0/1/5/6-title mixed shelves, all seven favorites and two down/up cycles, comparing IDs, slugs, descriptions, presentation, timestamps and picks exactly. It also saves/resolves 1,000 titles and rejects a 1,001-title update without altering stored picks.

Run only against a disposable schema-loaded SQLite database:

```sh
RAILS_ENV=test DATABASE_URL=sqlite3:/tmp/trove-shelf-migration-check.sqlite3 bin/rails db:schema:load
RAILS_ENV=test DATABASE_URL=sqlite3:/tmp/trove-shelf-migration-check.sqlite3 bin/rails runner spec/scripts/verify_shelf_display_migration.rb
```

Existing named-preview attachments are retained. The v2-to-v3 named fingerprint transition can require republishing before an old image is selected or the named shelf qualifies for discovery. Favorites retain their established v5 fingerprints. Operational limits are deliberate: no virtualized thousand-item grid or exhaustive discovery index is introduced.

## Visual concept and verification

[Concept](unified-shelves-concept.png) was generated with the built-in image tool as a UI design reference, not production artwork. Library reference `libfile_fca8841bee508191a4cadf50d266927f` was materialized into this Mac with current supported Library helpers; readable PNG bytes, Library attributes and actual pixels were verified. Only its ordered-cover hierarchy and sharing context informed the design. No Letterboxd branding/content, invented reviews, social metrics or new mascots are shipped.

Existing Trove palettes, navigation, approved assets and historical image layouts remain authoritative. Georgia editorial headings, existing application control typography, 44px action targets, 6px action radii and thin dividers form one component system. Desktop custom shelves use six columns, medium screens four and mobile two. Custom cover frames share a 2:3 geometry; artwork retains its native proportions using contain. Secondary owner links sit in a native disclosure rather than pushing primary content down a narrow screen. Image customization remains in a secondary disclosure.

Required adaptations from the concept: retain Trove's actual navigation and saved colors; use correctly paired approved catalog fixtures in synthetic local QA accounts; omit the generated avatar/About section/redundant detail-page overview; preserve existing image layouts and cover proportions. The light palette therefore remains the established Gallery palette. No generated cover art is a production asset.

Fidelity ledger and sign-off checks:

| Comparison | Final implementation evidence |
|---|---|
| Hierarchy and copy | Title, optional real context, actual count/mix/attribution, primary actions; generic custom-description filler removed. No invented eyebrow/social copy. |
| Components and geometry | Shared toolbar/header/media item/empty state; compact secondary menu; consistent action borders/radii/targets. |
| Type and long content | Serif heading/title hierarchy, explicit control sizes, 80-character headings and long/missing item titles wrap without line clamping. |
| Palette and assets | Existing saved palettes preserved; real fixture title/artwork pairs; full uncropped covers and readable missing-cover text. |
| Responsive layout | Six/four/two-column custom grid; owner/public desktop and 390px mobile inspected; 640px layout checked as the 200% reflow equivalent of a 1280px desktop. |
| Interaction/access | Keyboard reorder/focus return, native settings/menu disclosures, copy fallback/native-share path, saved appearance in visitor mode, loading/error/repeated-action regressions. |

IAB was the first visual inspection method; Selenium/Chrome ran the repository's system suite. Concept and final rendered PNGs were inspected with view_image. Screenshots live in [unified-shelves evidence](../screenshots/unified-shelves). Final exact-head CI status belongs to draft PR #684 checks; earlier green heads do not substitute for the final head.

## Preservation checklist

- [x] Seven fixed favorites and five-pick validation retained, including existing favorite OG fingerprints.
- [x] Named IDs, URLs, content, order and presentation preserved; additive reversible migration only.
- [x] Stored capacity, overview length and social-image cover count are separate.
- [x] Mix/display changes preserve selections; oversized legacy records remain editable.
- [x] Owner authorization and concurrency enforced server-side; visitors get read-only controls/payloads.
- [x] Catalog import does not create ownership; quick tracking/Profile/In Progress semantics untouched.
- [x] Keyboard reorder and final-removal focus, dirty-navigation and stale-save guards retained.
- [x] Current explicit named publication required for discovery; combined candidate and returned-row bounds explicit.
- [x] Desktop/mobile, light/dark, missing/long covers/titles, empty/one/five/six/twelve/large shelves exercised.
- [x] No merge, deployment, production migration or privacy-setting changes performed.

## Final local evidence

On Ruby 3.4.12 / Rails 8.1.4: 43 focused shelf request/service/browser examples passed; 98 JavaScript checks passed; repository lint inspected 671 files with no offenses; Brakeman reported no warnings. The final two-bound service follow-up passed all three service examples again and retained the measured five-query favorite budget. Migration preservation and 1,000-title capacity checks passed after the script’s final cleanup. The compact toolbar, changed settings-button label, default heading spacing and final cover-frame CSS are included in the exact-head CI run requested for final review.

Final IAB evidence covers owner/public/anonymous desktop, mobile, Gallery light palette, empty/one/five/six/twelve/72-title shelves, unclamped long context, keyboard menu/no overflow, copied-link feedback and 200% reflow equivalent. The overview appearance save was exercised through the actual UI and returned a saved state. Above-the-fold copy was compared with the concept/required adaptations; the removed-break whitespace issue was repaired and a regression assertion added. Concept and current render were viewed side by side; sign-off accepts the documented Trove-specific adaptations with no remaining known clipping, overflow, wrong artwork/title pairing or inert primary control.
