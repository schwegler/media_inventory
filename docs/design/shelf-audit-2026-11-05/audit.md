# Trove Shelf: audit and proposed experience

November 5, 2026. Expert walkthrough and source review; no participant usability study. The prototype is a proposal with simulated content and persistence, not a production implementation.

## 1. Executive diagnosis

Shelf's strongest job is **expressing a person's taste through a deliberate arrangement of media**. A good shelf says why these works belong together, makes their artwork inviting, and gives someone a reason to explore the curator. Named seasonal collections, mixed media, preserved artwork ratios, Mixtape, textures, approved mascots and shareable compositions already support that job. Keep them.

The main problem is conceptual rather than a shortage of customization. “Shelf” currently describes a public directory, seven fixed favorite lists, named collections, parts of the library, an editing surface and an exported image. An Overall favorite list can wear a seasonal headline that also titles the whole directory. People cannot reliably infer which object they are viewing, changing, saving or sharing. A second problem is that sharing combines distinct promises: copy a profile URL, open a native share sheet, make an image, and publish a shelf-specific social preview. A third is that state and navigation responsibilities are spread across one large controller and several rendering systems.

The direct Share report is reproducible. In deployed Chromium, native sharing is unavailable. The header Share button successfully copies the profile link but does not open a sharing interface. The toolbar Share link opens the lower details panel yet leaves the URL hash empty, the scroll at 0 and focus on the link; the sharing section remains 2,239px below the viewport. That is an observable blocked journey, not merely a styling preference. The screenshot's tiny ungrouped top links amplify the uncertainty.

**Direction:** keep the existing data identities, but present one owner workspace and one collection editor with Content, Appearance and Share sections. Public viewing is a finished exhibition. “Favorites” remains a separate concise expression of enduring taste; named shelves express a theme, season or project. Keep manual save until a coherent versioned draft contract can replace it. Do not introduce autosave piecemeal.

The accompanying focused PR repairs navigation/focus, sharing feedback, manual recovery and toolbar consistency, and corrects misleading link copy. The complete redesign below is an isolated proposal. No schema changes, production writes, merge or deployment belong to this deliverable.

## 2. Evidence scope and baseline

- Source: `schwegler/media_inventory`, default branch `master`, inspected `8b810e3c9f526a173f91c9e0fb7c9296ba418144`. Original `/workspace/media_inventory` checkout was clean on branch `work` at `3e33fe7`; all work is isolated in `/workspace/shelf-fixes`, branch `fix/shelf-share-navigation`.
- Read `AGENTS.md`, README setup/test instructions, database configuration, Shelf source/specs and the supplied 204-line brief. No feature-specific `.agents/skills` directory exists in the checkout.
- GitHub confirms #707, #720 and #721 merged. #707 repaired editor palettes and overview navigation. #720 intentionally made copied/native/export links point to the profile and restored visitor mascot selection. #721 added explicit owner appearance entry, scope, undo and section navigation. These improvements are retained. Documentation predating them contains obsolete five-item collection and style-carrying-link claims.
- Parent's deployment evidence identifies deployment 2284603 at this revision, successful 18:15 UTC. Independent live inspection confirms the expected controls and behavior; no independent deployment identity endpoint was found, so matching HTML is not itself a commit attestation.
- Supplied screenshot `image(20261105-184544).png` was materialized and its actual pixels inspected. It shows signed-in owner navigation on a public **Overall favorites** view, global headline “x-mas picks...”, five mixed picks, Christmas paper/Mixtape, two Share controls, lower Story preview, and public export mascot selection. It does not show a named collection editor. This distinction matters: “2026 Faves” is a separate named shelf on the live overview.
- Live read-only Chromium: exact supplied URL at 1280×900; default `/@schwegler/shelf` at 390×844. No page JavaScript errors captured; mobile overview had no horizontal overflow. Native share was undefined, clipboard present. No social post was sent. Browser trust was restricted to the environment's configured CA keys.
- Production owner writes were not attempted. Owner, signed-in non-owner and anonymous authorization/interaction checks use disposable local fixtures and existing request/system specs. A visitor preview flag is not proof of authorization.
- Browser checks represent desktop Chromium emulation, not physical iOS/Safari/Android or every theme permutation. Screenshots of real content remain internal evidence, not exported deliverables. New designs use simulated jackets and titles. Test execution and limitations are recorded in `verification.md`; suggested tests below are not claims of execution.

Evidence notation: **O** observed live/supplied pixels; **C** code-supported; **I** documented intent; **H** design hypothesis. Confidence describes evidence strength, not impact. Root-cause links below reference repository paths and symbols on the inspected baseline.

## 3. Current concepts, architecture and journeys

### Product purpose and boundaries

A Shelf lets a curator select, order and present works that express something about their taste. Its primary outcome is a coherent public collection worth exploring and sharing. Secondary uses are concise favorites, seasonal recommendations, personal thematic lists and image compositions. Favorites and named shelves already exist; explicit context explanations, integrated editing and proposed starter templates are design changes. Shelf selection does not mean ownership, a rating, consumption progress or a private library record. Those remain separate systems. Public selections should never imply a private library item or disclose a review/progress state.

### Current concept map

```text
Profile /@handle ── Shelf tab ── Public directory /@handle/shelf
                                   ├─ FavoriteShelf overall (manual, mixed, ≤5)
                                   ├─ FavoriteShelf media category ×6 (manual, ≤5 each)
                                   └─ ShelfCollection ×N (stable slug, own metadata/presentation)
Owner menu My Shelf ── /shelves workspace
                        ├─ create / settings / archive / restore named shelf
                        ├─ /shelves/:slug/edit → public template + owner controls
                        └─ favorites editor / appearance editor → same public template
Any exhibition ── copy/native → Profile URL
               ├─ canvas download → local PNG, first five picks per rendered group
               └─ owner publication → attached shelf-specific landscape preview
Title pages ── PublicShelfMembership → eligible public selections
Library / ratings / progress ── separate personal records, not required for picks
```

| Current label | Actual meaning | User-facing problem | Recommended treatment |
|---|---|---|---|
| Shelf / All shelves | Public directory of favorites and named collections | Singular headline can imply one collection | “Schwegler's shelves”; breadcrumb to profile |
| Overall | Independent mixed-media favorite list, not aggregate | Sounds derived from category lists | “All-time favorites”; explain independent selection |
| Favorite shelves | Seven fixed lists, each up to five | Same weight as thematic collections, even when sparse | Favorites section, one main list plus optional categories |
| Custom shelves | Named independent collections | “Custom” describes implementation, not user purpose | “Your shelves” in workspace; “Collections” on public directory |
| Shelves workspace / My Shelf | Owner-only management | Different names for same destination | “Manage shelves” consistently |
| Shelf headline | Account-wide heading for directory and favorites | Seasonal title appears to name everything | “Public introduction”; named shelf title is distinct |
| Appearance & share image | Persistence controls plus export tooling | Scope and outcome are mixed | Appearance section with scope; separate Share section |
| Copy link / Share | Profile copy/native vs local sharing section | Same label, different effects | “Copy profile link”, “Share profile”, “Share & export” |
| Publish share preview | Shelf-specific landscape attachment, plus discovery eligibility | Sounds like publishing the shelf itself | “Update shelf link preview”; explain shelf already public |
| Profile library shelf | Personal catalog presentation | Shelf also means curation | Label “Library” in navigation and instructional copy |

### Current technical responsibilities

`ShelvesController#show/load_presentation` resolves identity, saved presentation, category/overview, picks and preview attachment. `ShelfWorkspaceController` adds owner context, creation nonce, settings/archive/version checks. `FavoriteShelf` validates manual unique picks (max five) across six media types; `ShelfCollection` allows 1,000, preserves existing oversized records, and has a 1–12 overview preview count. Its preview count is not export capacity: `shelf_image.js#renderShelfImage` renders at most five picks per group. `favorite_shelf_controller.js` owns picking/import, search, ordering, save/version, presentation, history, copy/native, preview rendering and publication. ERB/Sass and canvas have separate layout/theme rules. `PublicShelfMembership` and `ShelfPublicationLookup` implement bounded discovery lookup; direct named links do not require current preview publication.

### Journey inventory

| Journey / entry | Actions, feedback and state | Exit and recovery / evidence |
|---|---|---|
| Discover, anonymous profile | Shelf tab opens directory; populated collections and favorites are public; “Make your own shelf” invites signup | Profile remains an alternative; purpose copy exists, but favorites vs collections is unexplained (O/C) |
| New owner, My Shelf | Username gate if absent; workspace offers Create your first shelf; title/context/mood form creates a stable identity | Redirect into empty editor, then add a title. Creation token handles repeat submit; invalid form retains errors (C, local specs) |
| Existing owner curate | Choose list; click empty slot/Replace/Add; search Trove catalog or external source by media type; select; reorder with earlier/later buttons; Save shelf | Explicit saving/saved/error status. Dialog close restores opener. Failed catalog import preserves query. External import creates catalog media, not personal LibraryItem (C) |
| Favorites vs named maintenance | Workspace separates defaults and collections; settings changes mix/preview count; archive requires exact title; restore preserves slug/picks | Archived public link unavailable until restore. Narrowing types retains existing picks. Concurrent settings detect version mismatch (C) |
| Appearance from public owner view | Customize appearance enters appropriate editor/deep link; choose theme/layout/advanced; save or undo | #721 already provides section focus, guard and snapshot handling. Favorites/directory share appearance; each named shelf is independent (C) |
| Public exhibition, any visitor | Artwork and title links reach media pages; category links and All shelves navigate; profile context visible | Empty named shelves hidden from directory; direct empty named URL still possible. No editing authorization granted to visitor mode (C) |
| Share/export | Header Share attempts native or clipboard; toolbar Share opens details; format/mascot/preview/download below | Live toolbar did not navigate to opened panel. Copy/native destination intentionally profile. PNG and shelf-specific OG preview are separate products (O/C/I) |
| Return later | Saved metadata/order/presentation come from database. URL styles only win before saved presentation exists; localStorage written but not restored on connect | Reload loses unsaved draft by design with navigation guard; hashes reopen sections. Arbitrary URLs should not be assumed saved (C) |
| Recovery | Save/version failures retain client picks/choices; import/search retry; image load timeout fallback; expired login returns unsuccessful fetch | Need dedicated stale/edit-session guidance and conflict resolution beyond generic reload; no claim of recovery tested on real production data (C/H) |

## 4. Prioritized findings and root causes

Severity: S1 blocked core task/access/data risk; S2 major recurring confusion; S3 friction; S4 polish. No confirmed data loss or authorization failure was observed.

| ID / severity / confidence | Scope and reproduction / expected → observed | Consequence, cause and remedy / verification |
|---|---|---|
| SH-01 · S1 · high | All public roles, desktop; click toolbar Share on exact live URL. Expected visible focused sharing controls → details opens, hash empty, scroll 0, section 2,239px below. O; controller `showSharing` only sets open. | Core action looks dead. Reuse #721's `navigateAppearanceSection`, explicit hash/focus/scroll; label Share & export. Verify repeated clicks after close, keyboard, Back/Forward and phone. **Focused fix.** |
| SH-02 · S2 · high | Public header Share in Chromium; no native API → clipboard succeeds, global status changes. Native API path awaits saving before share; rejection triggers another clipboard request; cancel silent. C/O. | No clear outcome or visible fallback; native activation may expire on network save. Immediate native invocation for saved state; block dirty/saving state with message; local status; cancel text; selectable manual URL. Unit-test promise rejection/repeat clicks and mocked browser capabilities. **Focused fix.** |
| SH-03 · S2 · high | Public header Copy link vs lower Copy profile link; advanced help promises style-carrying copied links. C/I #720. | Destination is deliberately profile, so current copy is false. Use profile-specific labels and explain image scope. Keep canonical profile URL. Verify actual clipboard/native payload has no query/collection. **Focused fix.** |
| SH-04 · S3 · high | Screenshot owner toolbar: six small plain links beside separate outlined actions; overview link has special owner styling. O/C `_toolbar`, accumulated Sass rules. | Weak grouping makes primary work hard to find. Uniform outlined nav links, 44px target, readable UI type/current/focus; reserve filled style for task action. Screenshot + keyboard checks across themes. **Focused fix.** |
| SH-05 · S2 · high | “x-mas picks...” appears on Overall and whole directory; selected picks are manual independent favorites. O/C `show`, `FavoriteShelf`, header. | A user may believe seasonal collection edits affect one named shelf. Separate public introduction from named title; rename Overall; show identity breadcrumb and scope. Preserve existing headline data; migrate labels only initially. Test distinct headings/routes. |
| SH-06 · S2 · high | Profile owner “Edit shelf selections” links public `category=overall`, which now intentionally displays visitor template. C `users/show:28`. | Misleading edit entry requires another action. Point label at actual favorites editor or rename “View favorites”; proposed phase 1 fix, not silently bundled. Request test route/role and end-to-end profile entry. |
| SH-07 · S2 · high | Publication lives on shelf layout OG image, while copied/native link opens profile; application layout uses `yield(:meta_image)`, profile does not supply shelf preview. C `layouts/shelf`, `layouts/application`, users view. | Updating a shelf preview does not establish what profile URL unfurl shows. Preserve profile default; explicitly explain shelf-link preview and its discovery role. Offer separately labeled direct shelf URL only as deliberate future capability. Test both destination metadata contracts; no claim of social cache refresh. |
| SH-08 · S2 · high | Collection supports 1,000 picks; settings overview count 1–12; canvas uses first five; `shelf_image` alt text explains truncation but primary action does not. C. | A full-shelf image expectation is unmet; preview length looks like export control. Label Overview covers separately and “Image includes first 5 of N”; preserve all content. Test N=0/1/5/6/12/1,000; never truncate stored picks. |
| SH-09 · S2 · medium | Editing uses combined public template; separate headline form, picks PATCH, presentation PATCH and settings submit have different save boundaries. C `show`, `save`, `savePresentation`, workspace form. | “Save shelf” can mean less than users assume. Proposed single explicit Save changes with one versioned payload for content+appearance, metadata settings clearly scoped. Keep existing manual saves until API contract exists; race/stale tests before consolidation. |
| SH-10 · S3 · high | `applyTheme` appends saved style parameters to every `data-shelf-link`, including workspace/settings; saved nonempty presentation entirely overrides URL. localStorage writes are unused on connect. C. | URL implies control it may not have and leaks irrelevant presentation context. Typed link policy: identity in URL; section hash in editor; saved presentation from destination; legacy styles honored only as existing fallback. Remove unused storage later with compatibility tests. |
| SH-11 · S3 · medium | Up to 1,000 collection picks all rendered in public/editor DOM; custom collection membership `items` can resolve all items for selected shelf; preview lookup instantiates owner attachment history in helper. C risk, no benchmark. | Large shelves may slow editing/preview and increase memory. Measure DB/DOM/render/cover requests at 100/1,000; add bounded pages/selection virtualization only if justified; never let canvas constrain public content. Performance budget is an acceptance hypothesis. |
| SH-12 · S3 · medium | Source has multiple cumulative shelf Sass blocks, separate canvas theme/layout normalization, broad controller; old docs still state both collections max five and copied links carry styles. C. | Fixes drift across page/export/docs. Extract share interaction, versioned presentation normalization and export manifest; keep rendering implementations independent. Contract tests and update current docs; historical design alternatives clearly dated. |
| SH-13 · S3 · medium | Sparse favorites cards contain five placeholder jackets even when real selections fewer; overview has significant dead space around collection imagery in mobile observation. O/C. | Empty placeholders can look like broken covers; density is uneven. Public cards show actual count/artwork only and explicit no-selection copy; owner editor keeps add slots. Validate missing art vs empty slot separately, long titles and 200%/400% zoom. |

Retain existing safeguards: server owner authorization; catalog imports independent of library; stable random-suffixed slugs on rename; archive rather than destructive delete; version checks and user locks; immutable snapshots during asynchronous saves; cover containment/fallback; reduced-effects handling; keyboard reorder; rendering work delayed until preview opened. Passing tests are counterevidence to broad claims that all customization is broken. The observed Share failure is specific.

## 5. Recommended model and flows

Considered: (A) improve the exhibition editor in place; (B) a dedicated workspace with one cohesive editor; (C) a freeform visual canvas. A is cheap but preserves confusing mixed public/editor responsibilities. C offers flexibility at high keyboard/mobile/state cost and adds unnecessary layout machinery. **Choose B**, keeping public exhibitions and existing Rails/Stimulus architecture.

The primary owner screen is **Manage shelves**. Main action: Create shelf. Show “Your shelves” first, then “All-time favorites” and optional media favorites, then archive. Each card has Edit and View; settings are inside the editor. New owner copy: “Make a shelf about something you love. Start with a title, add a few works, and make it yours.” Main action “Create your first shelf”; optional “Choose all-time favorites.” Creation asks title and optional context, with Everyday/Christmas/Halloween starting moods; media restrictions and overview cover counts remain advanced settings. No forced visual configuration.

The editor breadcrumb names the exact shelf. Content is default: Add titles, search source/type, selected count, move earlier/later/remove, optional lead note later. Appearance contains a theme preset and layout first; background and approved mascot choices under More appearance. A sticky Save changes bar says exactly what is unsaved. Preview as visitor is separate and restores editor location. Share is available when saved and explains the profile URL, image count and separate preview publication. Public pages expose curator, title/context, content links, All shelves, profile and Share & export; owner tools form a quiet authenticated management strip.

```text
CURRENT: Profile / menu → public overview OR workspace → editor OR settings
         public/editor → combined appearance + export → profile URL / PNG / shelf preview
         user must infer identity, save scope and sharing destination

PROPOSED: Profile → public shelves → finished collection → media / curator
          Manage shelves → Create(title + optional mood) → Content
          Content ↔ Appearance ↔ Share (same identity and draft)
          Save changes → saved public version → Preview as visitor → return to same editor
          Share → Copy profile / Share profile / Download image / Update shelf link preview
          Settings → rename/mix/overview count/archive → same stable identity
```

Christmas/Mixtape and Everyday/Gallery use the same controls and save model. The artwork and palette change, not the workflow. The prototype's visible annotations explain each design decision. Optional user notes, collaboratively maintained shelves and arbitrary canvas positioning are not essential to this model and are excluded from the core release.

## 6. Annotated designs and prototype

Open `prototype.html` through a static server or directly as a local HTML file. Everything is simulated and isolated: no API calls, accounts, analytics or real media images. It contains mixed-ratio synthetic jackets, both Christmas/Mixtape and Everyday examples, persistent-in-memory saved/draft state, empty/new-user mode, add/remove/order, appearance controls, visitor preview, Share dialog, manual profile copy fallback and explicit publication state. Reload resets the demo. Browser history switches screens; Cancel/discard leaves saved state intact. Simulated save failure is recoverable. Buttons marked simulated never post anywhere.

| Screen / annotation | Desktop specification | Mobile specification and transitions |
|---|---|---|
| Manage / 1 | Header + Create shelf; cards show title/count/theme, Edit and View; favorites below; new-user toggle demonstrates onboarding | Single column; Create stays first; full-width card actions. Create → editor, empty Content tab |
| Content / 2 | Breadcrumb identity, Content/Appearance/Share; count/capacity explanation; mixed-media tiles; visible ordered list and move buttons | Two columns where space permits, single at 320px; title and move controls wrap; search dialog uses full available width |
| Appearance / 3 | Live composition beside grouped presets; “Changes apply only to [title]”; advanced texture/mascot; sticky explicit Save/Undo | Controls precede preview; no side-scrolling radio grid; preview is optional scroll target. Theme switch preserves picks and other settings |
| Finished visitor / 4 | Curator → collection title/context → contained mixed art; quiet All shelves/Profile; one Share & export | Same hierarchy; actual sparse count, no fake media. Return to editing restores section and draft |
| Share / 5 | Profile destination visibly distinct from image and shelf-link metadata; portrait/landscape; “First 5 of N”; saved/publication statuses | Accessible dialog with close/Escape/focus return; actions stack; selectable URL if clipboard denied. Publication is independent of content visibility |
| Save/error / 6 | Dirty status survives edits; error says “Your changes are still here. Try saving again”; stale state requires comparison/reload in production | Sticky bar stays clear of content at zoom; error status announced. Retry saves existing draft; Undo restores saved content and presentation |

The prototype is interaction evidence for feasibility, not proof of usability or a production renderer substitute. Proposed captions can be evaluated against the real export renderer in engineering. Synthetic art deliberately demonstrates proportions and missing artwork without copying the owner's private editing screenshot into deliverables.

## 7. State, persistence, permissions and compatibility contracts

### Existing baseline, verified from code

| State | Authority / precedence / trigger | Public effect and navigation |
|---|---|---|
| Category / collection / overview | URL: active collection takes priority; valid category selects fixed list; absent/invalid category on public show becomes overview | Identity survives direct links; collection slug stable on rename; archived lookup unavailable |
| Favorite picks | `FavoriteShelf.picks`, manual ≤5, type restrictions, Save shelf PATCH | Public immediately after successful save; category and overall independent |
| Collection picks / title / description | `ShelfCollection`, up to operational capacity ≥1,000; title≤80/context≤240; settings and picks separate saves | Public immediately; archive hides, restore preserves identity; changing mix retains existing excluded types |
| Theme/layout/texture/companion | Entire nonempty saved collection presentation or account shelf presentation wins over URL; otherwise URL normalized; defaults midnight/exhibition/clean/auto | Favorites share account presentation; named independent; no automatic seasonal time decision. Auto companion resolves from theme |
| Client appearance | Controller draft, writes localStorage but no connect restoration; owner Save appearance PATCH; visitor can alter mascot locally | Unsaved editor choices guarded; visitor mascot not persisted; format is export-only and defaults portrait |
| Published image | Explicit owner landscape PNG attachment keyed by category/theme/style/signature | Shelf-specific OG lookup; missing/stale gives site fallback. External crawlers may retain old URL/image caches beyond app invalidation |
| Discovery | Confirmed username + attachment candidates; named shelf needs matching signature; bounded recent candidates | Editing invalidates matching named publication; republish restores eligibility, subject to candidate window. Direct active shelf stays public independently |

### Proposed contracts for the complete redesign

| Domain | Authoritative source / scope / precedence | Write and navigation | Visitor, failure and fallback |
|---|---|---|---|
| Identity | Existing record IDs/slugs; favorites keep category key | Creation once; stable slug on rename; editor paths private context, public route unchanged | Old direct links continue; archive returns unavailable without disclosing owner editor; restore revives same URL |
| Picks/order | Ordered typed IDs, no derived synchronization to library/favorites | Draft Content edits; one versioned Save changes transaction for content+appearance | Saved order only; removed catalog items render unavailable caption/count policy, do not silently reassign positions |
| Metadata | Named title/context on collection; account introduction separately labeled | Explicit Save; settings version token; shared identity across title and preview | Escaped text; long titles wrap; URL survives rename. Invalid form retains entered values |
| Presentation | Collection saved config, else documented legacy URL fallback; account defaults only for favorites | Draft in editor; Save changes; defaults copied at creation rather than live-coupled inheritance | Visitors see saved version; export-only changes labeled temporary; approved legacy themes/layout values retained |
| Save status | Saved revision + draft revision; one in-flight transaction; optimistic version | Dirty → Saving → Saved or Error/Conflict. Edits during save stay dirty; saved snapshot is submitted snapshot | Never mark newer draft saved; failed save retains draft; expired session offers sign-in and recovery, not blind resubmit |
| Undo / reset / cancel | Last successful snapshot; default preset is a separate explicit action | Undo changes restores snapshot; Reset appearance previews defaults then requires Save; Cancel prompts only if dirty | No destructive content reset hidden behind appearance. Navigation discard affects local draft only |
| Permissions | Server current user and record ownership on every write | Public preview changes no authorization; CSRF on writes; owner-only editor noindex/cache policy | Non-owner/anonymous cannot mutate, even forged IDs; requests test server behavior independently of absent buttons |
| URLs/history | Public identity only, optional legacy normalized style; section hash for editor navigation | Back/Forward restores section; same-section click reopens/focuses without duplicate entry; leave guard for dirty draft | Profile share URL remains canonical `/@handle`. No owner tokens/version/draft in links or PNGs. Invalid style falls back, never 500 |
| Share destination | Profile for default Copy/Share and image footer, per #720 | No implicit save from native gesture; prompt to save first; call native in gesture; manual selectable link on rejection | Native cancel leaves page usable; unsupported native copies with visible feedback; blocked clipboard never looks successful |
| Export manifest | Immutable saved identity, first five displayed picks, normalized presentation, requested format and canonical profile | Portrait/landscape create downloadable image only; artwork timeouts caption fallback | Count/truncation explicit; alt text matches exported subset; no fake picks; no CORS tainted export or hidden social posting |
| Shelf preview publication | Explicit shelf-specific landscape asset for saved revision | “Update shelf link preview”; content remains public before publication; signature invalidates after edit | Clearly not the profile URL unfurl. Cached social clients outside control; show last published revision/stale status and retry |
| Renderer parity | Shared normalized manifest/test fixtures, separate DOM and canvas layouts | Golden contract fixtures and geometry checks; no new theme engine | Preserve contained art and semantic captions; missing cover text and approved mascot choice consistent |

Required API change for consolidated editing: add a versioned payload accepting picks and presentation atomically, reject stale updates without partial writes, return new version plus submitted snapshot identity. No schema migration is inherently needed for that step. A durable server draft or conflict comparison UI would need a separately scoped design; do not store sensitive draft data in public URLs. Optional published-at/revision display can derive from attachments first; add schema only if history requirements demand it.

Compatibility: keep old routes, keys, slugs, valid saved configurations, six media types, archive state and all picks. Introduce display labels before structural changes. Do not convert Overall into a derived list, rename slugs, or collapse category records. Old presentation URLs retain current fallback semantics; document that saved owner appearance wins. Republish can refresh app preview eligibility but cannot force an external service to evict a cached image. Renamed usernames remain a wider account-link compatibility concern; this audit proposes no unverified alias migration.

## 8. Dependency-ordered engineering plan

Effort is relative: S 1–2 focused days, M several days, L roughly 1–2 weeks including review, not a commitment.

| Phase / package | Problem and intended result / code | Dependencies, compatibility, effort | Observable acceptance |
|---|---|---|---|
| 1A immediate sharing + toolbar | Repair SH-01–04; focused PR controller, shelf views/Sass/specs | No migrations; preserve #720/#721; S | Both actions produce the named result; section visible/focused; native/clipboard reject recoverably; top targets ≥44px |
| 1B identity and truthful entry labels | SH-05/06/08; profile links, headings, workspace copy, export count | Inventory current labels; no record or slug changes; S | Owner reaches correct editor from profile; can state collection vs favorites; image subset disclosed |
| 1C preview contract and docs | SH-07/10/12; shelf/profile metadata specs, current docs, typed link helper | Preserve profile default; decide optional direct link only after design review; S/M | Profile/shelf unfurls independently tested; no style-travel claim; irrelevant params absent from management links |
| 2A editor shell and responsive sections | One identity + Content/Appearance/Share; small ERB components, Stimulus section controller | After phase 1 labels; retain old routes as entry redirects; M | New user creates and adds useful mixed picks; existing owner finds saved shelf and returns from visitor preview |
| 2B atomic save contract | Combined versioned transaction; Rails update service and draft controller | Before unified Save; no required schema; M | Concurrent/stale test rejects whole update; pending edits remain dirty; retry/undo never lose selections |
| 2C curation and scalable overview | Search/source context, capacity/truncation, actual sparse cards; models/services remain typed | 2A; benchmark before pagination; M | Local/external add does not add ownership; ordering keyboard works; 1,000-pick shelf remains editable without truncation |
| 2D appearance and export parity | Scoped presets + advanced controls; shared manifest normalizer; separated share controller | 2A/2B; keep legacy options/assets; M | Christmas/Mixtape and Everyday produce coherent page/image/alt text; format/mascot do not cross-save scopes |
| 2E publication/recovery | Saved vs stale preview; explicit retry and auth/stale handling | 2B/2D; optional attachment metadata only; M | Public before publication; named discovery pauses/restores; profile URL promises remain accurate; error retains draft |
| 3A scale optimization | SH-11 measured query/DOM/cover work | Benchmark 100/1,000 first; no speculative virtualization; M/L | Set measured regression bounds; bounded DB work and responsive controls at supported capacity |
| 3B expression enhancements | Optional shelf notes, starter content prompts, image subset selection | After core usability evidence; preserve order and links; M | A test user can explain preserved identity and subset; no expansion ships without a clear task benefit |

**Smallest coherent release:** phase 1A plus truthful labels/counts and corrected entry destinations from 1B/1C. It fixes the dead-looking action and prevents the UI from misrepresenting destination or identity. The complete phase 2 should ship in independently reviewable changes behind an isolated preview until atomic save and parity tests pass. No speculative large redesign is included in the focused implementation.

Verification plan uses existing RSpec request/model/system, Node tests and Chromium helpers. Request/model: forged non-owner update, stale token, media validation, archive/restore, preview invalidation, no LibraryItem side effect. Frontend: exact native invocation timing, copy fallback, cancellation, repeat click, detached responses, edits during save, manifest parity, hash history/focus. End-to-end: new owner→first mixed collection→save→public→share; existing favorites and named contexts; anonymous/non-owner read and forbidden mutation; search dialog Escape/focus; stale/error retry. Visual: 320/390/768/1280 widths, 200%/400% zoom, all palettes for contrast, representative Gallery/Feature/Mixtape, long headings, no/sparse/full art, portrait/square/landscape covers, missing/slow/CORS art, both PNG dimensions, approved mascots, reduced motion and keyboard reorder.

Success criteria are tasks, not polish ratings: newcomer can find/create/add/save a meaningful shelf; owner can identify what Save changes affects; visitor recognizes curator/context and reaches media/profile; share output matches named destination/appearance. Expert walkthrough is not user research. A follow-up study should observe 5–8 new/existing users with both example moods, record task completion, mistaken destinations and recovery, then establish time baselines. Proposed targets such as ≥80% unaided first-shelf completion or fewer than one mistaken destination per session are hypotheses until measured. Return usage can be evaluated later with existing consent-respecting metrics; a new analytics platform is unnecessary.

## 9. Verification and remaining decisions

See `verification.md` for actual commands, outcomes and final PR/CI head. No production writes, migrations, merge, deployment, social post or real account changes were performed. Live reproduction was anonymous; signed-in owner behavior is verified only to the extent listed in local fixture checks. Safari/iOS activation and actual social crawler caching remain unverified.

No routine design choice needs to block the focused fix. Before any broader implementation, approve the proposed product contract as a concrete package: retain independent favorites and named shelves, keep profile default sharing, distinguish shelf preview publication, and unify saves only with a versioned transaction. An optional direct shelf-link action is a future decision, not a reversal of #720 hidden in this PR. Real usability results may change labels or hierarchy; preserve identities and content while iterating.
