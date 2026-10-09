# Speed Racer performance configuration

The Fly machine uses 256 MB RAM and 512 MB swap. `swap_size_mb` belongs at the top level of fly.toml (not inside `[[vm]]`). Docker installs and preloads jemalloc. Puma runs one process with 1–3 request threads, and automatic imports, source searches, and metadata refreshes share one in-process background thread. Production uses the SQLite URL's adapter rather than forcing PostgreSQL.

Provider responses are streamed into a body capped at 2 MB, with two-second connection and three-second read timeouts. Search requests have an overall deadline. Metadata responses are cached on disk for seven days, search responses for fifteen minutes. Stale responses use ETags when supplied. Explicit metadata refreshes revalidate immediately. Cover downloads retain their separate byte cap and streamed import path. URL hashes prevent API credentials appearing in cache filenames.

The browser uses asynchronous autocomplete polling with a 300 ms debounce and immediate loading state. Search does not fetch full details for every result; details are fetched after saving the selected media item. Library buttons update their label and selected state while Turbo saves, and restore them with a toast on HTTP/network failure. Turbo morphing, prefetch, navigation transitions, poster skeletons, lazy images, and reduced-motion behavior are configured.

Catalog pages contain 25 items, with a global pagination ceiling of 30. Profile and collection shelves contain 24 items. Shared-library comparisons run in SQL and load only four display records. Composite indexes match user collection, backlog, and public media filtering. Episode and issue library states are loaded together to remove per-child queries.

## Local verification

Production configuration with jemalloc, SQLite and 200 synthetic catalog entries completed 90 catalog requests across three concurrent clients with no HTTP failures. RSS was approximately 109 MB before requests, peaked at 134 MB, and ended near 129 MB after garbage collection. This used Rails integration requests in a local production process, not a deployed Fly machine. Browser checks exercised successful optimistic updates and HTTP 503 rollback at desktop and mobile sizes, with no JavaScript page errors. Console warnings came from existing Google Analytics CSP violations and the expected simulated HTTP 503.

## Operational limits

Swap provides headroom, not a guarantee against OOM kills. Confirm RSS on the actual Fly machine with live provider/import bursts before assuming the 180 MB target holds for every workload. No deployment was performed.

The Async adapter does not persist queued jobs across process restarts or Fly auto-stop. A lost search expires and can be retried; a lost metadata refresh can be retried after its cooldown. Cover imports also have their existing recovery path. Durable delivery requires a database-backed queue and a separate capacity decision. There is one worker thread, but the waiting job queue is not capped.

Cached response files may contain provider data and tokens embedded in returned upstream URLs; keep the cache private. Periodically run `Rails.cache.cleanup` on the persistent volume to remove expired entries. HTTP timing and payload limits do not cover every third-party social SDK. Existing on-demand legacy cover recovery can still fetch remotely on the first image request.

The local memory check and browser screenshots do not establish a universal 60 fps guarantee. Verify frame timings on representative devices; skeletons animate transforms, controls use scale transforms, and motion is disabled for reduced-motion preferences.

## Test evidence

The combined RSpec run exercised 502 examples. All 38 browser examples passed; nine existing examples remain pending. Its only failure was a controller test double missing the newly used `api_id` field. After correcting the double, all 31 focused regression checks passed, including that example, like responses, profile rendering, and HTTP cache behavior. An earlier full non-browser run passed 464 examples with no failures and nine pending examples.

Sass compilation, Zeitwerk eager loading, Fly TOML parsing, and RuboCop checks of 19 changed Ruby files passed. Playwright used installed system Chromium because the Browser plugin is unavailable. QA used localhost port 3100 at desktop 1440 × 1000 and mobile 390 × 844. Page identity, meaningful content, successful optimistic status/like updates, and HTTP 503 rollback were checked. No framework error overlay or JavaScript page errors appeared. Existing Google Analytics CSP violations remain outside this change.
