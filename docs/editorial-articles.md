# Cached taco ’bout it stories

Related reading on all eight catalog detail routes uses `EditorialArticle` and polymorphic `EditorialArticleTitle` rows. It never becomes a user review or contributes to ratings. Rendering reads at most six cached articles and performs no WordPress requests. Featured images load directly in the browser with no referrer; no image proxy/download or fetch-policy expansion is added. Missing or rejected image metadata gets a landscape text placeholder.

## Import contract

The public `https://tacobout.online/wp-json/wp/v2/posts` REST API is authoritative. IDs are stable WordPress IDs, unique in the database. Each import atomically updates metadata and replaces the article's exact catalog associations, including multi-title roundups. Recognized HTTPS Trove links must use the configured public `HOST` origin (default `https://trove.schweg.xyz`), a known title route and an existing numeric database ID. Readable slug suffixes and document fragments are accepted; query strings, relative URLs, name searches and other origins are not. Unmatched links remain unmapped; reimport the same window after resolving catalog records. No title-name inference or upstream URL navigation occurs.

Only explicit `publish` posts with explicit unprotected content (and no protected excerpt flag) are accepted. Draft/private/trash/protected responses suppress existing articles and remove their associations. A rotating recheck of known IDs is necessary because the published list cannot report unpublishing. Only a post-specific 404/410 or explicit hidden metadata confirms suppression. 401/403, network errors, malformed payloads and transient failures retain the safe cache. Rechecks also include previously suppressed articles so republication is discovered.

The dedicated client reuses the existing HTTP streaming/size/deadline implementation with a strictly narrower endpoint validator: exact `tacobout.online`, HTTPS/443, only the posts collection and numeric post endpoints, no redirects, no authentication. The shared provider allowlist and CSP remain unchanged. Requests have a 15-second deadline, at most 2-second connect and 3-second read/write timeouts, and a 2 MiB body limit. Network failures, 429 and 5xx get at most three attempts with 0.25/0.5-second backoff. Other HTTP errors are not retried. Text is flattened, executable elements removed and lengths bounded; Rails escapes stored text again. Links require the exact article host. Images require the site's uploads path on the exact site host or its three standard WordPress image CDN hosts; they are never fetched by the server.

## Bounded operator commands

No scheduler, production invocation, deployment or automatic initial import is included. The following examples are for a disposable local database. Release approval, migration and production import/scheduling are separate operational decisions.

```sh
# Initial archive window: at most two pages of 25 posts.
bin/rails editorial:sync
# Output: imported, invalid_ids, next_page, after, before; watermark only when complete.

# Continue using the EXACT same AFTER/BEFORE/PER_PAGE and returned next_page.
PAGE=3 BEFORE=2026-10-24T04:00:00Z MAX_PAGES=2 PER_PAGE=25 bin/rails editorial:sync

# Incremental window, AFTER taken from the last completed watermark.
AFTER=2026-10-24T04:00:00Z bin/rails editorial:sync

# Rotate through at most 25 existing IDs, oldest checked first.
LIMIT=25 bin/rails editorial:recheck
```

Keep the returned window and continuation in the operator's run record. The commands intentionally do not persist or advance a global watermark automatically. `MAX_PAGES` is 1–20, `PER_PAGE` 1–50, and recheck `LIMIT` 1–100. Stop when `next_page` is null. Advance AFTER only to a completed window's `watermark`; invalid posts withhold that watermark and exit nonzero. Replay an interrupted/failed window; upserts are idempotent. Incremental filters overlap by one second to include modifications sharing the boundary timestamp. Listing failures exit without a completion watermark; previously imported pages remain safe to replay. Recheck reports failed IDs and exits nonzero while rotating checked timestamps to avoid starving the rest of the cache.

WordPress uses offset pagination, so edits during a multi-run archive scan can shift pages. Repeat bounded archive passes to reconcile archive coverage; do not treat absence from a page as deletion. Recheck frequency/budget determines how quickly unpublishing is reflected, so run it alongside incremental syncs and size the rotation for the desired freshness. Neither command runs on page requests. A source outage can leave last-known published cards visible until successful revalidation.

## Verification

`spec/services/editorial` covers idempotency, pagination/resume, modified filters, mapping replacement, roundups, unresolved links, malicious text/URLs, missing metadata/images, bounded retries, failures and confirmed unpublishing. Request coverage renders all eight routes, checks escaping and review isolation, and asserts no sync client is constructed during page rendering. `spec/system/editorial_articles_system_spec.rb` exercises section navigation, landscape artwork and fallback, two-column desktop and one-column mobile layouts, overflow and browser console health using synthetic cached articles and a local image fixture.

Read-only source inspection on 2026-10-24 confirmed REST IDs, protection flags, GMT date/modified metadata and embedded featured images (including `i0.wp.com` URLs). No live posts are fixtures and no production imports were run.

## Title-page hierarchy

Related reading follows My Library in the same main content column, before full details and episode/issue collections. A horizontal landscape image and readable headline replace the narrow desktop mini-rail; the source/tools sidebar aligns consistently with the rest of the page. Mobile uses the same tracking-first order, with 18px headlines and a reserved thumbnail rather than an oversized stacked card. Child pages place reading after My Progress. The smaller desktop overview is retained. Pages without articles retain their existing overview sizing and main-column library layout.

The newest story is visible initially; additional stories remain available in a native keyboard-accessible disclosure. Landscape artwork, date, excerpt, canonical links and full accessible headline text are retained. `#from-tacobout` and the on-page navigation remain intact.

For titles with stories, title facts, linked credits and provider details share one information surface with quieter secondary headings. Long provider descriptions use the wider prose row, and short facts stay aligned at the top beside longer content. No metadata is removed or hidden. Structured-only roles and extra contributors remain available; the earlier duplicate-credit filtering is retained. Episodes/issues, pagination, tracking, public progress, ownership formats, metadata tools, reviews, comments and community sections are unchanged. No import, authentication, session, schema or scheduling behavior changes.

Visual regression coverage includes 1440×1000 desktop, the supplied 647×2047 screenshot dimensions and 390×844 mobile. The capture fixture uses the Lupin/related-article text shown in feedback; local comparison runs can supply the existing public cover/article image through `READING_QA_COVER` and `READING_QA_IMAGE`. CI uses local fixture artwork. `READING_QA_PHASE=before` is an explicit baseline-capture mode; normal runs assert the repaired layout. Screenshot files and geometry measurements are retained under `UI_QA_DIR`.
