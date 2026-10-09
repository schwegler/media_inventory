# Video Game Section TLC: audit, implementation and operations

Checked 9 October 2026 against this repository. This delivers an image-first collection and tracking slice with working code. It does **not** claim completion of every feature in the mission brief.

## Repository audit and root causes

The app uses Rails 8.1, Ruby 3.2.3, SQLite by default, PostgreSQL where DATABASE_URL selects it, Hotwire/Stimulus, Active Storage and Administrate. No new queue, storage vendor, microservice or paid dependency was introduced. Production defaults to Rails' process-local async job adapter; it is not a durable queue.

Before these changes:

- `MediaSearchService` searched Steam, RAWG, Wikipedia and Internet Archive sequentially. Search enriched results, but its merge preferred Steam's tiny search capsule over the detail endpoint's artwork. Successful metadata did not verify image availability.
- `MediaController` returned remote URLs for web results. `thumbnail_fetcher_controller.js` hotlinked them and replaced errors with `/favicon.svg`. `MediaCoversController` also served that favicon when recovery failed. The source-branded orange diamond was the app's fallback, not a downloaded game cover.
- `MediaCoverImporter` already had host checks, byte limits, content hashes, Active Storage reuse, two process-local download slots and legacy Steam URL recovery. Marcel checked signatures but did not decode pixels. Failed downloads were swallowed without a persisted failure reason or bounded job retries. Source-to-blob caching disappeared with the process.
- Historical Steam `library_600x900.jpg` paths were guesses. Live Vampire Survivors Store responses use hashed paths under `store_item_assets/steam/apps/1794680/…/header.jpg` and `capsule_231x87.jpg`. The application must consume returned candidates rather than manufacture a path.
- Game identity was one `api_id` string. Title/year deduplication could collapse distinct same-title games. Steam's `music` content type was not distinguished from a base game.
- `video_games` was a shared catalog; `library_items` contained personal collection flags, rating and review. There were no copy, playthrough, session or journal tables. Logging an already-shared game could overwrite catalog fields. Game creation synchronously fetched details in an after-commit callback.
- Existing modal code already provided debouncing, Enter/Space selection, focus trapping, labels and mobile scrolling. It was reused.

## Implementation sequence and delivered code

1. **Validate and localize artwork.** Actual image responses are streamed within size/deadline limits, MIME-checked, decoded, bounded by pixel and ImageMagick resource limits, oriented and normalized into WebP up to 600 × 900 without enlargement. Content-addressed blobs deduplicate normalized bytes. `media_artwork_sources` durably records source URL hashes, blob references, retrieval time and attribution; cached URLs are local Active Storage proxy URLs. Remote originals are not retained by this pipeline. User-uploaded originals retain the existing storage behavior.
2. **Separate metadata from artwork.** Steam/RAWG metadata adapters declare implemented capabilities, isolate failures, cache successful/failed requests, enforce per-provider budgets and use a short circuit breaker. Transient metadata failures receive one deadline-bounded retry with jitter; rate-limit responses are not immediately retried. Artwork has a separate candidate resolver, priorities and provenance. A Steam app ID can resolve SteamGridDB portrait art while preserving Steam metadata. Known canonical external-ID mappings also bridge RAWG to Steam artwork. Without a shared ID, fallback requires exact title, release year, developer and confirmed base-game type; it never merges canonical records on that evidence. Internet Archive results remain available, but its generic service thumbnails are not accepted as game covers.
3. **Preserve existing catalog and user information.** Added canonical external-ID mappings with a unique `(provider, external_id)` index. Backfill previews conflicting IDs and never merges games. Logging a shared game preserves its existing catalog attributes. Initial enrichment runs in a job, fills gaps and preserves an explicitly selected cover. Existing provenance-aware metadata refresh remains available to owners.
4. **Add private tracking.** Multiple physical/digital/subscription/cloud copies have platform, storefront, edition, ownership state and purchase details. Playthroughs have independent progress/status/platform/difficulty/route/dates/notes. Sessions validate start/end times and derive duration; journals support spoiler flags. All new personal routes scope through the signed-in user's library. Purchase information, sessions and journals do not enter public activity feeds. Personal custom/alternate covers attach to `LibraryItem`, independently of shared catalog art.
5. **Deliver usable interfaces.** Responsive search rows show year, available platforms, content type, source and separate artwork source. Exact titles rank first; DLC/soundtracks are demoted and labeled. The log form captures ownership and current play status. The detail page shows synopsis/features/languages where supplied, tracking controls, cover upload/selection and repair. The catalog has title/type/library filters and title/release/added sorting. Personal statistics distinguish unique library games, explicit owned physical/digital copies and subscription access. Existing reviews/social/profile features remain in place.
6. **Support bounded portability and Steam import.** JSON exports include game identity, collection flags, copies, playthroughs/sessions, journals and external IDs. CSV exports contain copies. Import preview validates before any write; apply is transactional, append-only, idempotent for identical records and bound to the signed-in user. It requires a canonical ID that exists in this catalog; it is not cross-instance identity migration. Existing reviews/ratings are preserved rather than automatically restored from import. Steam public-library import uses an operator Web API key and explicit user authorization, preserves manual fields, records import counts/timestamps, and never deletes copies absent from a response. Steam aggregate lifetime playtime is labeled separately; no sessions are fabricated.
7. **Operate and verify.** Persisted cover health includes state, attempts and failure reason; jobs retry at most three times. Owners have cooldown-protected repair and alternate-cover actions. Admin game health reports cover/import counts, asset bytes, references, configured provider readiness, observed process-local adapter state and retry controls. Maintenance commands recover failed/pending/stuck remote imports, audit checksums/pixels and preview orphan cleanup.

## Database safety

Five additive, reversible schema migrations add game type/metadata, provider IDs, copies, playthroughs, sessions, journals, import health, Steam sync state and source mappings. Existing game/user/library primary keys, review/rating/ownership flags and catalog routes are preserved. No destructive automatic merge or legacy ownership inference occurs. The unique external-ID mapping can flag duplicates without discarding either game's user associations.

Before deployment, back up the database **and Active Storage files**, run migrations in the usual deployment workflow, and review:

```sh
bin/rails games:backfill
APPLY=1 bin/rails games:backfill
```

The first command is read-only. APPLY adds only unambiguous mappings. Legacy copy flags stay intact and are excluded from explicit-copy totals until manually reconciled. Reversing a migration after users start tracking will remove the new tracking tables; use the backup/export to recover those records. It will not remove the original catalog/library tables.

## Configuration and limits

See `config/game_tlc.env.example`. Steam Store requires no new key. RAWG requires an active `VideoGame` credential. SteamWebAPI is separate and disabled by default. SteamGridDB is separately configured and disabled by default: an API key alone does not enable caching. Its options must explicitly include `{"allow_image_storage":true}` after reviewing relevant artwork rights. This flag is an operator assertion, not automatic legal clearance or a license detector. Source attribution is stored and displayed.

Defaults: 60 requests/provider/process/minute; 6-hour game adapter cache; 15-minute combined search cache; one-minute metadata failure/circuit cache; five-minute failed search artwork cache; two concurrent downloads/process; first five visible result candidates acquire new covers; 15-second image acquisition deadline; 5 MB download limit; 20 million pixels; 64 MiB ImageMagick memory/map and no disk spill; five-second decode/transform budget; 512 MB remote-artwork quota; 100 pending/processing import records; three job attempts; five-minute repair/Steam-sync cooldown; one-minute alternate lookup cooldown; ten-minute signed cover choice/import preview; 1 MB import upload.

Request counters, circuits, cooldowns and previews use the existing FileStore, namespaced by Rails environment unless RAILS_CACHE_PATH overrides it. They are not distributed quotas. Storage/queue limits are conservative guards, not atomically enforced cluster-wide reservations. Supplemental acquisition is bounded to six provider-returned assets per request. Stored originals are normalized to bounded WebP; 180/360-pixel responsive derivatives are generated locally without downloading again. Active Storage's proxy supplies byte caching; collection recovery URLs keep the existing short cache policy. No claim of immutable caching for mutable game-selection URLs is made.

## Provider investigation and external constraints

Official pages were fetched during this work; successful documentation access is not a successful authenticated API integration. Plan limits and terms can change.

| Source | Verified/documented capability and access | Delivered status / constraint |
|---|---|---|
| Steam Store / Web API | Live Store search/detail fields and real images verified. [IPlayerService](https://partner.steamgames.com/doc/webapi/IPlayerService) documents owned-game access requiring a Web API key; game privacy still applies. | Store search/details/artwork are live-verified. Owned-game importer is fixture-tested only; no key/account was configured. Public import does not authenticate Steam identity. Achievements and recent-play integration are not delivered. Store endpoints are inherited, observed endpoints, not a promised stable public API contract. |
| SteamGridDB | [Official OpenAPI](https://www.steamgriddb.com/static/openapi.yml) documents bearer keys, platform-ID grid lookup, static type and 600×900 filtering. | Adapter/independent source selection tested with fixtures. No live key configured. Per-artwork rights and storage eligibility require operator review; no blanket permanent-storage entitlement assumed. |
| RAWG | [API documentation](https://rawg.io/apidocs) lists API keys, backlinks, a non-commercial free plan and plan-based monthly limits (20,000 on the displayed free plan). | Search/details/artwork supported, fixture-tested in this environment. No configured key for live checks. Existing use still requires a suitable plan and rights review. |
| IGDB | [Official docs](https://api-docs.igdb.com/) describe Twitch client credentials/bearer tokens, four requests/second and eight open requests. | Not implemented in this slice; credentials, terms and image rights must be reviewed before enabling. |
| GOG | [User Agreement](https://support.gog.com/hc/en-us/articles/212632089-GOG-User-Agreement) was accessible; no authorized public owned-library integration was established. | Manual storefront/copy tracking works. No protected client endpoints were scraped and no automatic account sync promised. |
| PCGamingWiki | The API information page returned HTTP 403 to this environment. | Access constraint preserved; no bypass or scraping adapter. Manual compatibility notes are available in private notes. |
| MobyGames | [Official API](https://www.mobygames.com/info/api/) documents MobyPro/API keys and plan limits: displayed non-commercial 720/hour with maximum 1/second, legacy 360/hour. | Not integrated; credentials, licensing and permitted image storage unresolved. |
| Wikidata | [Data access](https://www.wikidata.org/wiki/Wikidata:Data_access) describes CC0 structured data. Wikimedia images have separate rights. | External-ID model can retain mappings; no live matching/import adapter delivered. |
| Wikipedia / Wikimedia | Wikipedia search and genuine image downloads worked. [Commons reuse guidance](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia) requires complying with each file's attribution/license. | Existing supplementary search retained. Automated per-file license discovery is not implemented; Wikipedia fair-use covers must not be assumed freely licensed. Review existing caching policy before broader public/commercial use. |
| Giant Bomb | The [current API page](https://www.giantbomb.com/api/) says games/releases/companies and related APIs are currently unavailable following the platform rebuild. | External blocker, not an adapter to invent. No integration promised. |

## Troubleshooting and repair

Open **Admin → Command Center → Game integration health**. Configured means settings exist; `unprobed` is not proof of availability. Provider counters/circuits expire with the process. Cover failure reasons distinguish HTTP, invalid MIME/pixels, transformation, quota and filesystem failures without logging credentials.

```sh
bin/rails games:repair_artwork
bin/rails games:audit_artwork
APPLY=1 bin/rails games:audit_artwork
bin/rails games:clean_artwork
APPLY=1 bin/rails games:clean_artwork
```

Repair enqueues at most 50 records per invocation. Audit is read-only unless APPLY is set; it checksum-checks and decodes covers, and queues repair only for remote-managed corrupted assets. A personal/manual cover is never silently replaced. Cleanup previews only unattached `media-covers/` blobs older than seven days; APPLY removes their derived source mappings and blobs. Do not run cleanup concurrently with bulk imports; unattached search previews intentionally expire. Add scheduling through the existing deployment scheduler if desired; none is installed by this patch.

If imports remain pending after a process restart, the existing async queue may have lost its jobs: requeue using the maintenance task. An absent decoder makes imports fail explicitly; install ImageMagick (included in the updated Dockerfile). Do not treat a placeholder as imported art. Source failure never removes an already-persisted healthy cover or shared metadata. Refresh does not replace private user artwork, copies, sessions, journals or manual metadata overrides.

## Remaining mission scope

The full modernization remains larger than this slice. Concrete next dependencies are: permitted/credentialed IGDB and MobyGames adapters; Wikidata cross-provider identity review and alternate-title relationships; complete platform/release/edition/franchise/DLC graph; cross-process durable jobs, quotas and persistent provider metrics; achievement account authentication and hidden/rarity handling; signed/verified Steam identity connections and incremental background sync; acquisition trend/genre distribution reports; advanced showcase/profile layout customization; interactive unmatched-ID import reconciliation and recovery history; automated per-file licensing eligibility; full WCAG audit and non-Chromium testing; PostgreSQL integration verification.

These are unimplemented features or unverified capabilities, not silently successful integrations. Nintendo/Xbox purchases can be tracked manually now; no account-library synchronization is claimed. Existing catalog data remains usable without providers.

## Verification evidence

The five additive migrations were rolled back and reapplied in an isolated SQLite database. Existing user, game and library IDs, review text and physical-ownership flags survived. PostgreSQL has not been run in this environment.

Chromium was exercised through Python Playwright because the Browser plugin was unavailable. Desktop 1365 × 900 and mobile 390 × 844 checks covered searching for Vampire Survivors, rendering actual locally served WebP pixels, keyboard selection, saving ownership/playthrough details, logging a one-hour session and saving a private journal entry. Mobile had no horizontal overflow; the successful flow produced no browser console errors. Screenshots and scripts are retained under `/workspace/work/`. This is a focused smoke check, not a full accessibility certification.

Live search/image checks also covered Portal 2, Breath of the Wild, Halo Infinite and Cyberpunk 2077. All first results had real locally acquired covers. Zelda was a supplementary Wikipedia result with unknown game type; structured Nintendo metadata/account access was not verified. Observed cold-query latency was 4.57–15.90 seconds, so cold-search performance still needs improvement. No before/after benchmark is claimed. Credentialed RAWG, SteamGridDB and owned-library calls were fixture-tested, not live-tested.

RuboCop inspected 389 Ruby files without offenses. Rails autoload verification passed. The shared logging modal's delayed focus callbacks were replaced with immediate stage focus after browser tests exposed a race during rapid selection/submission. The targeted modal regression checks passed. Brakeman reported two weak-confidence SQL warnings in unchanged `UsersController` and `Admin::MergeMedia`; scanning the original HEAD reported the same two warnings. No new warnings were introduced. `git diff --check` passed. The review patch applies cleanly to original HEAD. Final full RSpec run: **537 examples, 0 failures, 9 existing pending examples**, seed 56426; line coverage 79.19%. Full output is retained in `work/full-test-results-final.txt`.

## Follow-up: personal library dashboard

The dedicated library now has cover-grid, compact-list and detailed-table layouts. Copy filters (platform, storefront, ownership state, access method) match the same ownership record; gameplay state, rating, title, developer, publisher, release year, genre and content type can also be filtered. Personal sorts include the user's actual date added, last recorded session, rating, recorded playtime and dated completion. Titles remain canonical and manual/user-selected covers are used in personal grid/list cards.

Saved views store only supported filter/layout keys and belong to the current user. Retrieval and deletion cannot access another user's view. Personal pages send `private, no-store`; catalog views do not include the user's copies, statistics or saved-view controls. View names are limited to 60 characters and 20 views per user.

Statistics are computed across the full personal library before filtering. Explicit permanent owned copies exclude subscription/cloud access. Started/completed counts use unique library titles, not session counts. Recorded session duration and imported provider lifetime playtime remain separate because the periods may overlap. Status categories are not mutually exclusive across multiple playthroughs; definitions are shown in the UI. Completion-by-year requires a recorded completion date. Owned access by platform includes subscription/cloud copies and is labeled accordingly.

Current master was merged into the draft branch. Its asynchronous search, conditional HTTP caching, bounded job worker, resource limits and unrelated profile/settings/series fixes were retained. Game autocomplete alone performs bounded details for at most five candidates to classify base games/DLC/soundtracks and recover real supplied artwork; other media retain post-selection enrichment. Async game searches acquire covers in the background search job. HTTP authorization headers are retained only on same-host redirects.

Focused collection and existing video-game browser tests passed (6 examples), and the shared integration merge tests passed (40 examples). Chromium desktop (1365 × 900) and mobile (390 × 844) checks exercised layout changes, saved-view creation/restoration/deletion and the compact list, without JavaScript errors or document overflow. The mobile table scrolls inside its labeled focusable region. Browser plugin was unavailable; Python Playwright was used. Screenshot evidence remains outside committed source under `/workspace/work/game-library-*.png`.

Full regression verification after merging current master and adding the dashboard: **546 examples, 0 failures, 9 existing pending examples** (seed 56426).

## Follow-up: acquisition, organization, gameplay and portability

Copies now record acquisition source, gift status, region and physical condition, in addition to purchase date/price/currency; all are private. Purchase details can be corrected from the copy editor. Tags and favorites support personal filters and saved custom collections. Sessions record optional enjoyment (1–5), mood and end-of-session progress snapshots. These snapshots do not silently change another playthrough's current status. Playthrough editors expose platform, difficulty, route and start/completion dates. Sessions and journal entries can be corrected or explicitly removed through user-scoped routes.

Manual completion milestones are first-class private goals with descriptions, spoiler flags and completion timestamps. They are explicitly separate from platform achievements; no achievement rarity, provider unlock or synchronization is fabricated. JSON/CSV portability includes the supported acquisition and session fields, imported lifetime totals, tags/favorites and manual milestones. Existing personal records remain append-only during import. A new library entry can restore ratings/reviews and organization fields; an existing entry never has those overwritten. Import never enables public gameplay sharing.

Portable JSON imports resolve existing external-ID mappings rather than trusting a foreign catalog's numeric ID. Conflicting or unmatched provider identifiers are rejected for review. Internal-ID-only imports reject a supplied title that disagrees with the destination record; title-only reconciliation is never used. Preview and transactional application remain in place. Artwork binaries and saved views are not carried inside this single-game export.

A dedicated public game shelf is linked from the existing member profile. It requires a confirmed member, the existing public library flag **and** the new explicit public-gameplay flag (false by default). Only game title, selected cover, favorite marker, rating and playthrough status/progress render. Purchase details, tags, journals, milestones and session notes do not. Disabling either visibility flag immediately excludes the entry. The public shelf supports favorite/playing/completed filters.

Admin game merges now preserve external mappings and transferred library histories. Overlapping library records for the same member block the merge for manual review rather than hiding one record or discarding reviews. Enrichment success/unavailability is persisted in existing metadata-health records, and the admin dashboard reports never-enriched games and metadata states. SteamGridDB now shares bounded retry/circuit/negative-cache handling with the metadata adapters; bearer headers remain isolated on cross-host redirects.

Validation for this increment: **553 examples, 0 failures, 9 existing pending examples** (seed 56426); 407–408 Ruby files checked during development, without offenses after fixes. Brakeman reports the same two baseline weak-confidence SQL warnings, with no new warnings. The new migrations passed an isolated up/down/up check preserving original library IDs, ratings, reviews and ownership flags. Focused ownership/privacy/import/reconciliation/provider checks passed (34 examples). Tablet (768 × 1024) and mobile (390 × 844) Chromium checks verified preference updates and manual milestone creation/completion/removal, with no JavaScript errors or page overflow. Screenshots are outside source under `/workspace/work/game-milestones-mobile.png`.

## Follow-up: typed artwork and responsive local images

Metadata and images remain independently sourced. Supplemental acquisition uses provider-returned Steam landscape/background/screenshot URLs and eligible SteamGridDB hero/logo/icon responses tied to a known Steam identifier. It is explicitly requested, bounded, and preserves existing artwork when a provider fails. Typed artwork also supports private uploads, platform box art and edition covers; private uploads are scoped to the owning library entry. Artwork credits and available source links render in the gallery.

Images are validated, normalized, content-deduplicated and quota-checked. Responsive 180/360-pixel renditions are generated from stored pixels without another provider request, preserving aspect ratio and transparency. Signed rendition URLs prevent guessing private assets by numeric ID; missing derivatives fall back to the original and enqueue one regeneration. Cleanup retains derivatives while their originals remain attached. Run `bin/rails games:prepare_images` to prepare existing covers and retry failed/stuck image jobs. Supplemental assets and their derivatives share the existing storage quota.

Full suite: **560 examples, 0 failures, 9 existing pending examples**, seed 56426. Focused tests cover real WebP decoding, aspect ratio/transparency, content deduplication, failure preservation, private upload ownership, signed recovery and safe cleanup. Chromium desktop/mobile checks exercised real Steam supplemental downloads, private upload/removal and local responsive image selection without console errors or page overflow. Credentialed SteamGridDB calls remain fixture-tested rather than live-tested. Brakeman retains the same two baseline weak-confidence warnings.

Artwork migration passed an isolated up/down/up check. Rails eager loading passed; RuboCop inspected 421 files without offenses. Final artwork-focused checks passed (8 examples), including explicit failed-rendition retry without duplicate jobs.

## Follow-up: canonical identity during logging

Logging a provider result now resolves known external-ID mappings before creating a game. Conflicting primary/mapped/local identities are rejected for catalog review. Explicit local autocomplete selections carry a signed 30-minute token, including games without provider IDs. Tampered, expired or deleted selections fail without mutating the library. Shared canonical metadata and existing personal history remain intact. Manual same-title entries create distinct catalog records rather than silently combining releases; users can choose an existing local result to reuse it. Changing the search title or choosing Add Manually clears stale provider and catalog selections.

Focused identity and shared inventory regression checks passed (26 examples after correcting the test time-helper setup). Mobile Chromium verified a real local selection followed by Back, title change and manual entry: the signed selection and provider ID reset, with no browser errors or page overflow.
