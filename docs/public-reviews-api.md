# Public reviews for WordPress

`GET https://trove.schweg.xyz/api/reviews` returns JSON without authentication or cookies. Server-to-server requests (including WordPress `wp_remote_get`) need no CORS headers or API key. This read-only endpoint has no publishing or deployment effects.

```sh
curl --fail --silent --show-error -D - \
  'https://trove.schweg.xyz/api/reviews?limit=3'
```

`limit` defaults to 3. Positive decimal integers are accepted and capped at 20; missing, zero, negative, fractional, and invalid values use 3. The envelope is `{ "reviews": [...] }`; no matches returns an empty array.

## Response schema

Each review contains:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Stable `library-item-<id>` identifier, unchanged by edits |
| `body` | string | Nonempty plain text; HTML tags stripped and entities decoded |
| `rating` | number or null | Stored star rating, e.g. 4.5; null when unrated |
| `rating_scale` | object | `{ "min": 0, "max": 5 }`, five-star scale |
| `published_at` | string | UTC ISO 8601 timestamp of first public written publication |
| `updated_at` | string | UTC ISO 8601 library-entry update time (also changes for non-review edits) |
| `reviewer.display_name` | string | User's display name |
| `reviewer.profile_url` | string | Canonical public HTTPS profile URL, using handle when available |
| `media_type` | string | `Movie`, `TvShow`, `TvEpisode`, `Album`, `Comic`, `ComicIssue`, `VideoGame`, or `Book` |
| `item_title` | string | Catalog title; episodes and issues include parent context |
| `item_url` | string | Canonical HTTPS catalog item URL |
| `review_url` | string | Canonical HTTPS dedicated review URL; use this for review links |
| `cover_url` | string or null | Absolute HTTPS Trove cover proxy URL when the item has a cover source or attachment |

Missing optional rating and cover values are always JSON `null`. Cover URLs use Trove's existing cover-serving route; upstream artwork availability can still affect the image response. URLs use the configured public `HOST` HTTPS origin, falling back to `https://trove.schweg.xyz`, never the caller's Host header.

## Selection, privacy, and ordering

Reviews are queried from `LibraryItem`, independent of activity volume. Only explicitly `is_public: true` entries with nonempty written text, an existing user, an existing supported catalog item, and an existing parent for episodes/issues qualify. Rating-only, whitespace-only, markup-only, false/null-public, deleted, dangling, and unsupported records are excluded, even for an authenticated owner.

Trove currently has public user profiles and public catalog/library listings, with no separate user or library privacy flag. `LibraryItem.is_public` controls review/rating visibility; collection status, game activity sharing, and account confirmation are not review privacy gates. This endpoint follows those rules and does not expose legacy review fields on catalog records or consumption history snapshots.

Order is `review_published_at DESC, library_items.id DESC`. New reviews receive publication time on the first save with written text and public visibility. Edits, library additions, hiding, and republishing preserve that time, so edits do not bump reviews. Deleting and recreating an entry creates a new review ID and publication time.

Historical public written reviews are backfilled from the earliest `reviewed` activity attached to their library entry, falling back to library-entry creation time. Historical activity can reflect a rating rather than written publication; this is a best available approximation, since the previous schema did not store publication time. Previously private entries get a timestamp when first made public after migration.

## Caching and conditional requests

Responses include a representation-derived ETag and `Cache-Control: public, no-cache`. Caches may store the response but **must revalidate on every use**, including when serving stale data would otherwise be possible. There is no server-side cached payload or freshness window. Every request queries current visibility and builds the current representation before evaluating `If-None-Match`; unchanged representations return `304`, while privacy changes, deletions, edits, and changed output fields return a new `200` representation when they alter the result.

```sh
curl --fail --silent --show-error -D - \
  -H 'If-None-Match: W/"<etag-from-previous-response>"' \
  'https://trove.schweg.xyz/api/reviews?limit=3'
```

For WordPress, keep the ETag alongside the last response, send it on the next request, and reuse the body only after a successful `304`. Replace it on `200`. Do not serve a WordPress transient or rendered page containing reviews without revalidation; on request failure, omit the review widget instead of displaying stale private content. HTTP validation cannot retract copies already downloaded or override an integration's independent page cache. Escape the plain-text body and titles when inserting them into HTML.
