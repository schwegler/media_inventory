# Media sources and stored covers

All six catalog categories search through `MediaSearchService`. The browser makes one debounced, abortable request to `/media/autocomplete` instead of repeating provider queries. Results include source attribution and provider-specific IDs; metadata enrichment merges only missing fields for the same title and release year. Provider failures do not stop the remaining sources. Admin book searches now use this same flow.

Default sources:

| Category | Sources |
| --- | --- |
| Movies | TMDB (key), iTunes, Wikipedia, Internet Archive |
| TV shows | TVMaze, TMDB (key), iTunes, Wikipedia, Internet Archive |
| Albums | iTunes, MusicBrainz / Cover Art Archive, Wikipedia, Internet Archive |
| Video games | Steam, RAWG (key), Wikipedia, Internet Archive |
| Comics | ComicVine (key), Open Library, Wikipedia, Internet Archive |
| Books | Open Library, iTunes, Wikipedia, Internet Archive |

Enable/disable sources per category in API settings. Existing settings/tokens are preserved when seeding. Keyed sources with blank tokens are skipped. Open Library comic queries filter by the comics subject. Wikipedia supplies supplemental artwork. Original source links are retained. Internet Archive supplies additional public collections for every category, with category filters for feature films, classic TV, album/netlabel audio, software libraries, books, and comics.

Steam search uses its returned `tiny_image`, without guessed portrait paths or per-result detail requests. Selection fetches app details, using the returned header/capsule image. Backfill repairs the old `library_600x900.jpg` URLs using app details too.

## Storage and resource limits

Only saved selections are imported, including episode and issue images. Search thumbnails are temporary remote previews. Saved views and public sharing metadata use stable app cover URLs. The image endpoint imports legacy covers on first use, then redirects to Active Storage; no manual backfill is required for images to appear. Unavailable sources return a local image placeholder with a one-minute retry cooldown. Page rendering never downloads remote images. `thumbnail_url` retains the source URL as provenance.

Downloads stream to temporary disk files with a 5 MiB cap, 15-second deadline, short connect/read timeouts, and at most three redirects. Actual file signatures must identify JPEG, PNG, WebP, or GIF; remote SVG and HTML are rejected. Fixed HTTPS provider domains are checked at every redirect, preventing submitted URLs from targeting arbitrary/internal servers. Unsupported hosts can be added to `MediaSources::Http::HOSTS` after review, or the user can upload a file directly.

A shared two-slot semaphore bounds background and on-demand imports together. The default asynchronous adapter has two workers (`MEDIA_IMPORT_THREADS`, default 2, capped at 4); an explicitly configured queue adapter is preserved. Configure the `media_imports` queue's concurrency in that backend when replacing the default adapter. The built-in asynchronous queue is in-process and does not survive restarts: run the backfill task to recover missed imports, or configure a durable Active Job backend for production.

Metadata and recent source-to-blob mappings share a bounded 16 MiB process-local cache, with 15-minute search and seven-day import-map TTLs. Binary files are never put into the cache. Blob keys use SHA-256 of content to reuse identical files; repeat imports skip existing covers. Manual uploads and selections made while a download is running take precedence. There is no eager download of whole search catalogs, full-resolution Wikimedia originals, or image resizing/transcoding dependency.

## Rollout / backfill

Run in the desired environment:

```sh
bin/rails media:seed_sources
TYPE=VideoGame AFTER_ID=0 LIMIT=100 bin/rails media:import_covers
```

Repeat with the printed `AFTER_ID` until exhausted. The task processes downloads sequentially, defaults to 100 rows, and caps a batch at 500. Run for `Movie`, `TvShow`, `Album`, `Comic`, `Book`, `TvEpisode`, and `ComicIssue` as needed. Existing attachments are preserved; failures report `unavailable` and can be retried. Backfill is optional to warm storage ahead of traffic; normal image access recovers legacy records and missed background imports automatically. Imported attachments whose underlying files are missing are recovered from their recorded source; manual uploads are preserved. Historical HTTP provider image URLs are upgraded to HTTPS and still pass the provider allowlist.

`bin/rails media:prune_covers` removes only imported blobs that have been unattached for at least seven days, in batches of 100 (maximum 500 via `LIMIT`). Use it periodically to reclaim files from abandoned selections; attached/shared images and manual uploads are preserved.
