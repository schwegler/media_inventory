# Large TV episode imports

## EastEnders investigation

The public EastEnders page (`/tv_shows/145-eastenders-1985`) showed zero episodes during the October 22, 2026 investigation. Its visible details include BBC One, a 1985 premiere and Status Running. TVMaze search resolves the matching original show to [show 793](https://www.tvmaze.com/shows/793/eastenders), distinct from its spinoffs.

The [TVMaze episode response](https://api.tvmaze.com/shows/793/episodes) downloaded during the investigation contains 7,333 episodes and is 3,760,108 bytes. Trove's normal JSON limit is 2,097,152 bytes. Replaying those exact bytes through the existing HTTP reader raises `MediaSources::Http::Error: Response too large`. Both initial TV sync and explicit metadata refresh previously fetched that one list. Initial sync caught the error and left episodes absent; refresh treated unavailable child data as partial metadata. Small parent-details responses can therefore succeed while no episodes appear.

The source has 42 seasons numbered 1985 through 2026. Those are valid source season numbers, not array indices to renumber from 1. The [season API](https://www.tvmaze.com/api#show-seasons) splits the list into much smaller responses; the downloaded 2026 season was 124,528 bytes. An offline replay grouping the downloaded episode rows by the source season IDs returned all 7,333 original provider IDs, without production writes or further provider requests. The largest season in that replay was 162,437 bytes.

**Production evidence boundary:** the public page does not expose the stored `api_id` or last metadata-refresh state, and this executor has no installed production shell/log client. The oversized TVMaze path is a confirmed code defect and reproduces with the matching show's real provider data. To confirm this record's exact failing path, an authorized production reader must inspect TvShow 145's source ID and refresh state. A blank/incorrect ID, disabled source or a `tmdb_` mapping requires its own diagnosis; this change does not guess or rewrite identities. TMDB's separate season limit is unchanged.

## Fix and limits

`TvmazeEpisodeList` preserves the normal single-request path for small lists. Only an oversized episode-list response falls back to the show-season index and season episode endpoints. Both initial sync and metadata refresh use it. Global byte limits, approved hosts, redirects, credentials, source activation, cooldowns and authorization remain unchanged.

The fallback requests newest seasons first and keeps their source season/episode numbers. It excludes specials, matching the original episode-list default. Every response retains the existing JSON limit. The fallback has a 30-second shared request window unless the caller provides an earlier deadline, and aggregate limits of 200 seasons and 20,000 episodes. Truncation, invalid season entries, failed seasons and rate limits are reported as partial. Already fetched seasons are retained; existing database episodes are never deleted.

Ended-season responses reuse the existing seven-day bounded cache, while new/open seasons are revalidated on explicit refresh. A later explicit refresh can continue beyond a previous rate limit without repeatedly downloading all ended seasons. Historical provider corrections can wait for cache expiry; normal per-episode detail refresh remains available. No automatic bulk retry or production backfill is introduced.

The existing reconciler preserves child identities, custom titles, reviews, comments and personal tracking. Its existing policy for a library entry marked fully watched is unchanged. The tests cover both entry paths, repeat refresh, partial provider failure, byte guards, all 42 seasons, year-numbered season filtering, bounded page instantiation and browser pagination/Back.

## Repair scope before production execution

Do not run a blanket metadata backfill as part of deployment. First obtain the read-only source ID, episode count and MetadataRefresh state/provider for TvShow 145. Also assess whether any library entries mark the whole show watched, since the existing completion policy applies to newly imported children.

A safe offline test imported the 7,333 downloaded rows into a separate SQLite test database in approximately 31 seconds, with a total process peak RSS of 241,748 KiB. It queued 7,432 follow-up jobs (episode enrichment plus artwork) in the test adapter, executing none; no provider network requests or production writes occurred. This is a local measurement, not a production capacity guarantee. Production queue limits and enrichment capacity must be assessed before requesting the single show's repair. Basic episode import and all follow-up enrichment are separate outcomes.

After code review and a separately authorized deployment, use a controlled single-show refresh under the existing cooldowns, monitor episode counts/partial state and queue capacity, and repeat only as necessary. This PR does not change production records or settings, and does not perform that repair.
