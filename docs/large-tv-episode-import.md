# Large TV episode imports

## EastEnders investigation

The public EastEnders page (`/tv_shows/145-eastenders-1985`) showed zero episodes during the October 22, 2026 investigation. Its visible details include BBC One, a 1985 premiere and Status Running. TVMaze search resolves the matching original show to [show 793](https://www.tvmaze.com/shows/793/eastenders), distinct from its spinoffs.

The [TVMaze episode response](https://api.tvmaze.com/shows/793/episodes) downloaded during the investigation contains 7,333 episodes and is 3,760,108 bytes. Trove's normal JSON limit is 2,097,152 bytes. Replaying those exact bytes through the existing HTTP reader raises `MediaSources::Http::Error: Response too large`. Both initial TV sync and explicit metadata refresh previously fetched that one list. Initial sync caught the error and left episodes absent; refresh treated unavailable child data as partial metadata. Small parent-details responses can therefore succeed while no episodes appear.

The source has 42 seasons numbered 1985 through 2026. Those are valid source season numbers, not array indices to renumber from 1. The [season API](https://www.tvmaze.com/api#show-seasons) splits the list into much smaller responses; the downloaded 2026 season was 124,528 bytes. An offline replay grouping the downloaded episode rows by the source season IDs returned all 7,333 original provider IDs, without production writes or further provider requests. The largest season in that replay was 162,437 bytes.

**Production read-only verification:** TvShow 145 stores TVMaze `api_id: 793` and has zero episodes. MetadataRefresh 226 uses TVMaze and is `partial`, requested at `2026-10-22 19:40:40.812119 UTC` and completed at `19:40:45.530971 UTC`. Its `succeeded_at` marks parent refresh completion, not successful episode import. There is no persisted error field. Available Fly logs cover only 20:08–20:09, so the exact historical exception is not observable. The verified identity, deployed full-list path, partial state and real-response reproduction strongly support the size limit as this record's cause; they do not establish a logged historical exception. No identity is rewritten. TMDB's separate season limit is unchanged.

## Fix and limits

`TvmazeEpisodeList` preserves the normal single-request path for small lists. Only an oversized episode-list response falls back to the show-season index and season episode endpoints. Both initial sync and metadata refresh use it. Global byte limits, approved hosts, redirects, credentials, source activation, cooldowns and authorization remain unchanged.

The fallback requests newest seasons first and keeps their source season/episode numbers. It excludes specials, matching the original episode-list default. Every response retains the existing JSON limit. The fallback has a 30-second shared request window unless the caller provides an earlier deadline, and aggregate limits of 200 seasons and 20,000 episodes. Truncation, invalid season entries, failed seasons and rate limits are reported as partial. Already fetched seasons are retained; existing database episodes are never deleted.

Ended-season responses reuse the existing seven-day bounded cache, while new/open seasons are revalidated on explicit refresh. A later explicit refresh can continue beyond a previous rate limit without repeatedly downloading all ended seasons. Historical provider corrections can wait for cache expiry; normal per-episode detail refresh remains available. No automatic bulk retry or production backfill is introduced.

The existing reconciler preserves child identities, custom titles, reviews, comments and personal tracking. Its existing policy for a library entry marked fully watched is unchanged. The tests cover both entry paths, repeat refresh, partial provider failure, byte guards, all 42 seasons, year-numbered season filtering, bounded page instantiation and browser pagination/Back.

## Bounded episode-only recovery (not executed in production)

Do not run a blanket backfill or normal single-show refresh for this repair. A normal offline reconciliation of all 7,333 downloaded rows took approximately 31 seconds and queued 7,432 enrichment/artwork jobs in the test adapter (none executed). Normal reconciliation also propagates whole-show watched flags. This local measurement is not a production capacity guarantee.

`TvmazeEpisodeRecovery` is an operator-only, create-only alternative with no route or automatic job. It defaults to a read-only preview, validates the saved show against an explicit expected TVMaze ID and the source activation setting, and fetches only the season index and the selected season. Existing HTTP byte limits and a shared 15-second deadline apply. Each batch is capped at 250 regular episodes, with an explicit episode-number cursor. An apply requires the exact preview digest; changed source data aborts before writes. Existing episode rows are skipped entirely. A transaction locks the show and rechecks its identity before creating missing rows.

Recovery omits artwork assignment, episode enrichment jobs and whole-show completion propagation. It does not edit library items, consumption passes/entries, activity, reviews, ratings, private notes or existing episodes. It leaves historical MetadataRefresh 226 unchanged; catalog repair does not turn a past partial refresh into a success. Normal sync behavior remains unchanged. An offline replay of all 7,333 downloaded episodes through 42 bounded recovery batches took 28.06 seconds, preserved every provider ID, queued zero jobs and created zero cover imports or library items. It used a separate local database with provider networking disabled. This validates the job-free path, not production capacity or authorization.

After review and a separately authorized deployment, an authorized operator can inspect one current-season batch in a Rails console:

```ruby
show = TvShow.find(145)
repair = TvmazeEpisodeRecovery.new(show, expected_api_id: '793', season: 2026, batch_size: 50)
preview = repair.call # read-only; review counts, source identity, cursor and digest
```

Stop after this preview until the specific production write is authorized. On authorization, apply only the reviewed batch:

```ruby
result = repair.call(dry_run: false, expected_digest: preview.fetch(:digest))
```

Verify created episode count and provider IDs, skipped-existing count, unchanged personal records and no added follow-up jobs. Decide the next season/cursor explicitly from `next_after_number`; do not automatically loop through 42 seasons. A source failure or changed digest means stop and inspect a fresh preview, not bypass validation. Start with 50 rows; the maximum of 250 is a hard ceiling, not a recommendation to import the entire show. Artwork/enrichment and any future full watched-state reconciliation require separate assessment and authorization. Parent production read-only investigation reference: `01a16539-ff87-7266-a0dc-5da404adf0e9`.

This PR performs no merge, deployment, production refresh or production write.
