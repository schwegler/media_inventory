# Absolute local cover selections

## Evidence (2026-10-20)

PowerWash Simulator 326 public HTML renders `/media/covers/video_game/326`, including the original artwork link and social image metadata. A GET of the original cover endpoint returned HTTP 200 `image/svg+xml`, the missing-game-cover SVG, and `Cache-Control: no-store` (request ID `46713cc7-6e0b-484d-8cb0-fbd8c7d6f44a`). Its CSP allows same-site and HTTPS images. This is a server-side missing result, not an omitted image tag or CSP-blocked image.

The supplied admin screenshot description shows a working current thumbnail and a remote source URL on the Trove origin at `/rails/active_storage/blobs/proxy/...webp`. The admin template displays that remote URL only when the record has no attached cover, and previews `thumbnail_url` directly. The public renderer instead goes through the catalog cover endpoint.

Before this fix, `MediaCoverImporter.local_blob` recognized only relative storage paths. An absolute Trove storage URL fell through to `MediaArtworkDownload`, whose HTTP provider allowlist excludes Trove. It therefore could not attach the blob even though the browser could display it directly. This is a reproducible explanation consistent with the supplied screenshot; the exact signed URL and live database association were not independently retrieved.

## Fix

Parse local cover references before matching storage paths. Relative paths remain supported. Absolute URLs must match the configured `HOST` HTTPS origin, including port, and have no credentials. Resolve signed proxy/redirect blob references and catalog cover references directly, without fetching the app over HTTP. Ignore query/fragment components when resolving the reference. Keep provider HTTP restrictions unchanged. Recognize an already attached selected local blob as ready.

The next ordinary cover recovery after release reuses the existing blob. No chosen artwork URL is rewritten and no duplicate artwork record is needed. Existing failed-recovery cache entries expire after one minute.

## Separate paths and limits

Admin cover search uses `MediaSearchService` and renders provider URLs directly; it does not use this import resolver. Blank Steam/RAWG previews require their exact URLs and image response/DOM evidence. Wikipedia working does not establish that the other providers share this failure.

This checkout has no title embed endpoint or WordPress shortcode implementation. The shared public review serializer publishes the stable `stored_cover_url` whenever a thumbnail or attachment exists; it does not check storage availability. The actual WordPress title endpoint, payload, shortcode cache policy and DOM are still needed to distinguish absent serialized artwork from cached absence or an image-fetch failure. No WordPress changes or cache flush were performed.

Production inspection used GET requests only. The existing cover GET itself invokes lazy recovery and can update import-health/cache state; no metadata refresh or catalog mutation endpoint was invoked. No merge or deploy was performed. PR #634 remains separate.
