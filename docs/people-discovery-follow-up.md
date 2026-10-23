# People discovery follow-up — October 23, 2026

## Evidence and diagnosis

The supplied Olivia Wilde screenshot was captured from:

`https://trove.schweg.xyz/entities/1962-olivia-wilde?role=&media_type=Movie&library=mine&commit=Apply+filters`

A focused browser-history lookup resolved the exact URL. Read-only live inspection
of `/entities/1962-olivia-wilde` as a guest showed 14 distinct catalog works:
*The Invite* (Actor and Director) and 13 *The O.C.* episodes (Guest star).
Thus movie associations and rendering already work for the imported movie.
The screenshot's personal-library filter is material: it does not request an
actor's complete filmography. This public inspection does not prove that every
expected movie is imported or that every older catalog credit is populated.
Account-specific production findings are excluded from this public audit.

Synthetic request/browser fixtures reproduce the empty personal movie scope
while the same movie is available in All Trove. They validate recovery without
adding a library item, changing reviews/ratings, or inventing credits.

## Delivered changes

- State explicitly when no works match **your library**. When the same role/media
  filters match catalog credits, offer a direct All Trove link, reset pagination,
  and retain the active filters. Retain a selected role even when it has no
  matches. No automatic scope switch, import, refresh, or personal-data write.
- Preserve the chosen library on discovery result links. Existing default
  personal-library behavior and private/no-store responses remain intact.
- Count distinct works in a SQL subquery instead of loading every credited work
  identity into Ruby; pagination and multi-role deduplication are unchanged.
- Default discovery's Category to People only when `kind` is absent. Explicit
  blank (All categories), other categories, searches and pagination remain valid.
- Remove a paired leading straight/curly double quote from collection display
  names and their SQL sort/search expression. Preserve source names, normalized
  identities, aliases, slugs, unpaired quotes, internal quotation and apostrophes.
  Apply the same display name to canonical credit links and matching context.
  Sorting happens before pagination, on SQLite and PostgreSQL.

## Backlog reconciliation

Current base: `origin/master` e5303813. No open PRs at inspection.

- PR #586 merged October 14: Movie/Book People, comic creator routing, issue links,
  album tracks and related metadata consistency already implemented.
- PR #593 merged October 14: metadata rendering/identity lookup and browser
  regressions already implemented.
- PR #611 and its SQL category/search/child bounds are in master. This follow-up
  only removes the remaining unbounded People work-count pluck; it makes no new
  production latency claim.
- PR #621 imported-metadata preservation and preview are in master.
- PR #640 merged October 21: canonical title metadata links already implemented.
- Notion Action Item **Default Trove discovery to People and clean storyline
  quotes** (`3fea99cf-980e-812d-97eb-ee485bd39487`, Not started on inspection)
  supplies the additional verified open scope and acceptance checks.

Existing architecture and consciously deferred provider/taxonomy work remain in
`docs/metadata-entities.md`. Full external filmographies, production backfills,
provider biography enrichment, entity merging, editions/variants, and unrelated
redesign are outside this PR. Production catalog repair requires a separate,
record-specific diagnosis and applicable authorization; no sweep runs on deploy.

## Verification

Regression coverage exercises movie/multi-role rendering, empty personal versus
catalog scope, private review isolation, unchanged library rows, role/media
preservation, category defaults/explicit choices, quote-aware search, deterministic
pagination, unchanged source values, and desktop/mobile navigation and overflow.
Browser captures use synthetic accounts and titles. CI runs the request suite on
PostgreSQL and the existing metadata browser suite, including the recovery test.
See the PR for final check results and responsive evidence.

## Separate dependency-audit repair

The first CI run stopped on unchanged `crass 1.0.7`. The maintainer advisory
[GHSA-pq4g-8rxf-4g29](https://github.com/rgrove/crass/security/advisories/GHSA-pq4g-8rxf-4g29)
identifies a CSS tokenization issue and fixes it in 1.0.8. A separately authorized,
conservative update changes only the crass version in Gemfile.lock, from 1.0.7 to
1.0.8. No other dependency versions, constraints, permissions, sanitization policy
or audit settings change. A fresh advisory database reports no vulnerabilities.
This records a CI dependency finding, not a claim of deployed exploitability.

No schema or security-policy changes, production writes, bulk imports, merge or deployment.
