# Metadata entities: architecture and provider audit

## Original architecture

Rails 8.1, SQLite development / PostgreSQL production, Active Storage covers,
Kaminari pagination, Administrate admin. Actor and Director pages share the
nonpersistent Category object at `/categories/:category_type/*name`. It splits
free-text columns and aggregates records in Ruby; roles have no stable identity,
aliases, biography, or provider IDs. Existing public URLs must remain resolvable.

Global SearchController, InventoryController catalog search, collection search,
shelf selection, and local autocomplete use separate title-only SQL LIKE queries.
GameLibraryQuery has additional personal filters. External autocomplete is a
separate, cached, bounded provider search (MediaSearchService + MediaSearchJob).
Admin command search and Administrate are separate surfaces. No dedicated search
engine or denormalized index exists. All shared catalog metadata is public;
LibraryItem contains user-specific tracking and review visibility.

MetadataProvider / MetadataRefresher manage explicit refreshes, provider-owned
values, cooldowns, conditional HTTP caching and status reporting. Series and
child metadata jobs also ingest independently. ComicIssue and TvEpisode already
have credits and details JSON, but those credits are neither linked nor searched.
Albums have no track model. ComicVine's first issue credits are incorrectly copied
onto the volume. Movie and album model callbacks duplicate parts of adapters.
Game providers already retain genres, features, tags, languages, and artwork.

## Design

Persistent MetadataEntity stores kind, normalized name, display name, stored
slug, aliases, description, local image and provider identities. MetadataCredit
is a polymorphic relationship to the actual work, with role, position and credit
details; AlbumTrack is a child work. A person has contextual roles, never a
role-specific identity. Music groups use contributor kind `artist`; organizations
and controlled categories use distinct kinds. Exact provider IDs take precedence;
only exact normalized fallback names coalesce, never fuzzy matches. Conflicting
same-provider IDs remain separate. Existing text and child JSON remain intact.

Legacy fields and structured provider credits synchronize transactionally on
save; a resumable local backfill populates older records without network calls.
Provider parsing belongs in adapters. Search uses indexed relationship subqueries
so pagination cannot multiply work rows. Track / issue / episode matches surface
the containing album / series without assigning child credits to the parent.
Canonical URLs follow the existing ID-plus-human-readable-slug convention.
Legacy category pages remain available with links to canonical entities.

## Provider capability inventory

This inventory is based on all repository adapters, fixtures, configured endpoint
shapes and their documented response fields. No production credentials or live
private-library payloads are available in this workspace; support is validated
with representative provider fixtures, not a claim that every provider supplies
every possible field.

| Provider | Media | Previously consumed | Available / missed | Approach |
|---|---|---|---|---|
| TMDB | Movies, TV | Top 10 cast, director, limited writers, genres, year, poster; season episode guest/crew JSON | Full cast/crew IDs, characters, producer/composer/cinematographer/editor, creators, all companies/networks, collection, languages/countries, original titles | Normalize structured credits/categories from current detail response; retain descriptive fields; preserve episode specificity |
| TVMaze | TV | Cast/crew flattened, first network, episode descriptions and guest credits | Person IDs, full roles, character names, network/web channel IDs, language/status | Normalize existing embedded cast/crew and guest responses |
| iTunes | Albums, books, movies, TV | Title, artist/author/director, genre/year/cover/URL | Album song listing via lookup entity=song, disc/track numbers, duration, artist ID, content flags, release date | Album lookup adds reliable song rows; no invented composers/featured artists |
| MusicBrainz | Music | First album artist, year, genre, cover | All artist-credit IDs, credited aliases, primary/secondary release types, release media/recordings, artist relations, label info, ISRCs | Release-group selects bounded representative release; release retrieves media/recording credits and relations |
| ComicVine | Comics | Volume publisher, first-issue creators flattened into volume; issue credits/detail JSON | Creator IDs, distinct roles, issue descriptions, story arcs, characters/teams/locations, dates | Preserve actual issue credits and normalize people / publisher / story arcs; avoid first-issue leakage |
| Open Library | Books/comics | Search title, authors, first year, first publisher, cover | Work author IDs/roles, subjects, edition contributors, ISBNs, pages, language, edition info | Work and bounded edition lookup using existing provider; distinct contributor roles |
| Steam / RAWG | Games | Developer/publisher/platform text, genre/tag/features JSON, synopsis, release dates, DLC IDs; Steam artwork | Structured company/platform/genre IDs, RAWG alternate names, series; navigation absent | Normalize reusable organizations/categories; retain useful existing details |
| Wikipedia | All | Search title, thumbnail, extract, URL | Unstructured article content | No speculative credit extraction; retain existing behavior |
| Internet Archive | All fallback | Title, creator, date, publisher, cover | Inconsistent subjects, identifiers and files | No inferred track lists or contributor roles from arbitrary files |
| Steam Web API / SteamGridDB | Games/import/artwork | Ownership/playtime, game identity and cached artwork | Not contributor providers | Preserve specialized existing pipelines |

Bulk enrichment is opt-in and paced, uses existing provider cache and refresh
status, accepts type/id/after-id/limit, and skips successful enrichment unless
forced. Deploy does not trigger provider requests. Unavailable/partial providers
remain visibly reported; old relationships and children are not erased on failed
requests. Entity images use the existing cover importer; pages never hotlink.

## Implemented surfaces and compatibility

- `/entities` offers name/alias search, kind and typed role filters, alphabetical
  or credit-count sorting, paginated responsive tiles, and a library selector.
- `/entities/:id-slug` groups actual credited works by media type and role, links
  individual issues/episodes and tracks, retains aliases, and shows locally
  cached provider images or a monogram. Signed-in users default to their library;
  all-catalog discovery remains available. IDs resolve renamed/colliding slugs.
- Existing Actor, Director, Writer, Genre and Platform URLs still render. New
  artist, comic creator, author, developer, publisher and network categories use
  the same infrastructure. Legacy category lookup remains readable during the
  staged offline backfill; no page request writes entities or fetches metadata.
- Media and child pages link canonical credits; albums show supplied track
  numbers, disc groups, durations and content ratings. Additional descriptive
  provider fields display with readable labels, not raw payloads.
- Global and per-type catalogs, personal libraries, public collections, shelf
  selection, local add-media autocomplete, issue/episode in-page filters, admin
  command search, and Administrate media search share metadata matching.
  Global search adds direct entity results and one matching reason per work.
  External autocomplete keeps the existing provider-specific discovery behavior.
- Exact, prefix and partial media-title matches precede contributor exact/prefix
  matches and aliases. Escaped literal searches and relationship subqueries
  prevent wildcard surprises and card/pagination duplication.
- Existing media merge tools preserve entity relationships; album merges move
  tracks and reject overlapping track identities safely. Provider identities
  distinguish company vs network IDs and developer vs publisher IDs.

The migration `20261014140000_create_metadata_entities.rb` adds four tables and
compact provider-credit/detail JSON on root media. It preserves every existing
column. Unique provider-identity and credit indexes enforce idempotency;
normalized-name and kind/name indexes support lookup. Separate preloading avoids
PostgreSQL DISTINCT/order problems when personal-library search joins are used.

## Rollout and maintenance

Apply the migration normally. Then perform the **offline** backfill in bounded
batches; this does not contact providers:

```sh
TYPE=Album LIMIT=100 AFTER_ID=0 bin/rails metadata:backfill_entities
TYPE=ComicIssue LIMIT=100 AFTER_ID=0 bin/rails metadata:backfill_entities
```

Run for each type (Movie, TvShow, Album, Comic, Book, VideoGame, ComicIssue,
TvEpisode, AlbumTrack); continue with AFTER_ID set to the last completed ID.
ID targets one record. Output includes type, ID and extraction/failure status.
Blank TYPE runs a bounded batch per type. Existing free-text delimiters remain
inherently ambiguous; structured credits preserve names such as AC/DC exactly.
No fuzzy/person matching is used.

Provider enrichment is separately opt-in. The existing refresh button also fills
new fields for individual library records:

```sh
TYPE=Album USER_ID=123 LIMIT=20 AFTER_ID=0 bin/rails metadata:enrich
TYPE=Comic USER_ID=123 ID=456 bin/rails metadata:enrich
```

USER_ID identifies the refresh actor; the task uses existing user/item cooldowns
and leases. Each attempted root refresh is paced by at least 21 seconds; INTERVAL
may increase this. Successful versioned enrichment is skipped. FORCE=1 explicitly
revalidates cached provider data, and rate-limited batches stop with a reported
status. Successful HTTP responses retain the existing conditional cache. The
extra MusicBrainz release lookup waits one second between requests. Existing
bounded child jobs retain their HTTP cache, queue and retry behavior. No new
provider or background sweep is activated on deployment.

## Verification

Meaningful graph, provider, request and browser tests cover canonical multi-role
identity, distinct provider IDs, aliases, preserved legacy URLs, actor/director
rendering, artist and comic creator navigation, issue/episode specificity, tracks,
search scoping/ranking/escaping, all shared search surfaces, duplicate-free
pagination, private-library isolation, admin merges and 390px layouts.

The inherited full suite contained 11 stale system-test failures on the untouched
base checkout. Those tests now exercise current labels, disclosures, edit forms,
menu selectors and image srcset failure handling while retaining their original
create/edit/delete, keyboard and artwork assertions.

Results: full suite **811 examples, 0 failures, 9 existing pending placeholders**;
PostgreSQL checks **87 examples, 0 failures**; final graph/browser checks
**28 examples, 0 failures**. RuboCop reports no offenses, Brakeman no warnings,
and bundler-audit no vulnerabilities.

Checks: full RSpec suite including Chromium browser tests; PostgreSQL graph,
provider, category, search and personal-library suites; RuboCop; Brakeman;
bundler-audit; Zeitwerk; Dart Sass build; schema load; real migration over old
records; repeated local backfill; git diff whitespace checks. No production
records were modified, and live credentialed provider responses were unavailable.

## Previously Available but Unused Metadata

| Media type | Previously discarded / unlinked | Now stored and displayed | Now searchable | Intentionally deferred |
|---|---|---|---|---|
| Music | Complete artist credits and IDs; release types/labels; release media/recordings, credits/relations, disc/track positions, durations, ISRCs; iTunes song lookup | Normalized album/track contributors, labels, track records, disc/track list, durations/content ratings and release details | Artist names/aliases, featured/relation contributors, labels and track titles surface containing albums | MusicBrainz release groups use one representative release, not every regional pressing; missing composer/producer credits are never inferred; complete work-level graph and alternate recording/version catalog remain follow-ups |
| Movies | Full cast IDs/characters and crew roles beyond truncated strings; companies and collection; original title/languages/countries/runtime/overview/IMDb ID | Normalized people with roles and credit details; organizations/collection and additional detail fields; provider images enter local storage | All normalized contributor/category/organization names and aliases | Keywords, distributor-specific data and per-person biography endpoints need selective product/extra-request work; languages/countries remain descriptive fields |
| TV | Full embedded cast/crew IDs, creators, all networks/companies; episode-specific guest/crew IDs and images | Shared people/organizations; child credits stay on episodes; language/status and provider details | Series and actual episodes match their own credits; series also surfaces matching child episodes | Season collection pages and richer entity biographies; existing eight-season request bound still reports partial coverage |
| Comics | Creator IDs, distinct multi-role issue credits and story arcs; existing issue credit JSON was unlinked | Canonical people/roles on actual issues, publisher organizations, story-arc collections; retained issue descriptions/dates/characters/teams/locations | Actual creators and story arcs return issues and their containing series | Characters, teams, locations and universes are valuable future entities, but need identity/taxonomy judgment; variants/alternate covers and fractional issue numbers require extending the existing issue identity model. Old volume text is retained even if an earlier import sourced it from issue #1 |
| Books | Open Library work-author identities and bounded edition contributors, ISBNs, pages, language and edition details; iTunes author IDs | Authors and supplied distinct Illustrator/Translator/Editor/Narrator roles, publishers; additional edition information | Every supplied contributor/organization name and alias | Provider metadata often omits narrator/illustrator/series roles; no audiobook narrator is invented. Subjects display as descriptive metadata pending a curated subject/genre mapping; editions/series-number normalization remains future work |
| Games | Structured developer/publisher/platform/genre identities and supplied series; existing organization/genre text lacked navigation | Normalized organizations/categories, linked credits plus existing game details/artwork | Developer/publisher/genre/platform/series names and aliases | These adapters do not supply person-level directors/designers/writers/composers. Existing DLC IDs remain descriptive relationships pending owned-base-game matching; RAWG tags/game modes and platform/region release graphs are follow-ups |

Additional deliberate omissions: comic characters/teams/locations/universes,
curated book subjects, game DLC/expansion relationships and regional/edition
variants. These are useful candidates, but promoting every provider tag/string
would create noisy pages and unreliable inferred relationships. Alias and
provider-identity tables support future conservative entity merging; a dedicated
entity-merge/correction admin UI remains a follow-up.
