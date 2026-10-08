# Editorial UI and metadata maintenance

The interface shares tacobout.online's local Instrument Sans / Space Grotesk typography, near-white/near-black canvas, ruled sections and violet editorial accent. Media Inventory remains an interactive catalog: restrained cover grids, persistent controls, concise metadata and responsive forms.

## Style architecture

`application.scss` composes named modules instead of appending an override sheet. `_tokens.scss` owns the semantic palette; `_foundation.scss` exposes Sass aliases for existing modules. `_editorial.scss` retains the original editorial layout intent. `_components.scss` owns shared interactions and media presentation; other modules hold established page structures. `_profile.scss` preserves the latest server-rendered profile navigation, readable user URLs and privacy-aware shelves while integrating the scoped theme.

Semantic CSS variables include `--canvas`, `--surface`, `--inset`, primary/secondary/tertiary text, border/strong border, accent/hover/subtle, on-accent, focus, positive, warning, destructive, info, link/hover, selection and overlay. Legacy variable names resolve to these tokens. Accent presets are violet, ink and moss; semantic success/error colors are independent of the chosen accent. Dark palettes use light accent fills with dark button labels. OS appearance remains supported.

Space Grotesk provides display/headings and Instrument Sans provides body and controls. Fonts are local. Page titles are fluid, long titles wrap, and metadata remains readable. The spacing scale is exposed as `--space-1` through `--space-8`. Fluid content containers, intrinsic media grids and wrapping action rows support narrow webviews through wide desktop screens. Albums use square frames; other covers use portrait frames, with contained source artwork rather than destructive cropping.

Buttons use primary, secondary, ghost, success and danger variants, plus compact, full-width and icon forms. Controls have visible focus, disabled/busy states and generally 44px minimum targets. Text links have deliberate underlines; navigation uses active underlines; card titles use quiet stretched links with accessible names. Status never depends on color alone. Menus support keyboard navigation and restore focus; dialogs trap focus, make the background inert and restore the trigger. The first keyboard stop is a skip link. Reduced motion and reduced effects suppress decorative transitions.

## Personal and profile preferences

Authenticated users edit their own preferences at `/settings/appearance`: light/dark/system, curated accent, comfortable/compact density, cover/row media presentation and reduced effects. Values persist on User with validated allowed values. The initial HTML contains the settings; Turbo copies the incoming body preference data to the root before rendering and clears stale cache entries when preferences change. No localStorage synchronization or external font fetch is needed.

Profile accents and linen/solid/minimal headers have a live preview and are scoped to the profile container. They do not change global navigation, accept arbitrary CSS or accept unsafe HTML. Existing avatar/banner uploads remain available in profile settings. Native iOS pages retain compact web tools for search/library/settings/categories because the current native tabs do not cover every destination. Tauri consumes the normal responsive HTML; its startup fallback also respects OS appearance.

## Safe refresh workflow

Six canonical media detail pages, and episode/issue pages through their parent, expose an Artwork & metadata disclosure. Authenticated users may POST a refresh for media allowed by the application's existing `can_access?` convention. The current catalog is shared; personal collection privacy remains separate. Anonymous requests require login. The endpoint selects from six fixed model types and uses only the stored source ID. It grants no editing/admin rights and cannot accept a provider class or provider URL.

Supported source paths:

| Media | Sources |
| --- | --- |
| TV | TVMaze numeric IDs; TMDB `tmdb_` IDs |
| Movies | TMDB IDs; iTunes IDs for stored Apple/iTunes sources |
| Comics | ComicVine volume IDs (`4050-` supported), issues by provider ID |
| Albums | iTunes numeric IDs; MusicBrainz release/release-group UUIDs |
| Books | iTunes numeric IDs |
| Games | RAWG `rawg_` IDs; Steam `steam_` or numeric IDs |

Configured providers use the existing active API configuration and credentials. Unsupported/missing identifiers do not trigger guesses. Google Books cover-search results and Wikipedia source IDs do not imply a supported canonical refresh adapter. Wrestling event refresh is not offered because the existing source integrations do not support it.

Refreshes run synchronously with bounded network work, using the current Rails/Hotwire architecture. Network open/read timeouts are five/ten seconds and provider work has a 45-second total timeout. A unique polymorphic refresh record and conditional claim prevent duplicate simultaneous refreshes of one item. Item requests have a five-minute cooldown; user requests have a twenty-second cooldown. A two-minute refreshing lease prevents a stranded state from blocking indefinitely, while the item cooldown still applies. These are application safeguards, not a distributed provider-wide request queue.

Reconciliation is transactional under a parent lock. Episode identities use season/episode; comic identities use provider ID with numeric issue-number matching for legacy records. Children are updated in place, never destroyed/recreated. LibraryItem ratings/reviews, watched/read flags, comments, likes, ownership, collections and existing titles remain intact. Parent bibliographic values fill blanks or update values previously supplied by that provider; titles are not replaced. External artwork URLs may be repaired, but attached user covers are preserved. Provider snapshots distinguish subsequent source changes from personal edits.

The refresh record stores provider, attempt/success times, state and prior source values. Feedback distinguishes success, unchanged, partial, provider unavailable, rate limited, unsupported, failed and cooldown. Turbo follows a redirect to an opened metadata disclosure; Stimulus explicitly scrolls to and focuses the result (Turbo fetch navigation may omit URL fragments), so the result is visible and refreshed children/artwork render immediately. Busy controls prevent accidental repeated submissions; server throttling remains authoritative.

TVMaze reconciles available episode records. TMDB work is capped at eight seasons per request; ComicVine at five pages of 100 issues. These bounds report partial coverage and retain old children. Comic issue numbers currently use integers: fractional issues are skipped and reported as partial rather than coerced into duplicate identities. Existing schema constraints remain unchanged. All external artwork accepted by refresh is HTTPS without embedded credentials. Broken artwork uses an actual image error handler, replaces browser error icons with stable fallbacks and never enters a reload loop.

## Migration and validation

`20261008170000_add_presentation_and_metadata_refreshes` adds defaulted preference fields, the per-user request timestamp, optional unique comic provider IDs and the metadata-refresh table. It is additive and uses portable Rails schema operations and JSON, with SQLite and PostgreSQL compatible queries. Existing `theme` remains the appearance source.

Regression specs cover authorized/anonymous refresh, provider selection and failures, cooldown/active claims, idempotence, preserved personal episode/issue state, uploaded covers, preference persistence/scoping, media editing, responsive navigation, broken artwork, tabs, dropdowns and modal focus restoration. Use `bundle exec rspec`, `bundle exec rubocop` and `bundle exec rails dartsass:build`. Browser checks should include light/dark themes, narrow widths, native-UA navigation, missing/dead artwork and metadata result states. Native binaries and real provider credentials need deployment-specific validation.
