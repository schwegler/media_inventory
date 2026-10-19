# Shelf discovery and sharing

Visitors see populated categories and collections, the saved title and presentation, intact covers, profile context, and a modest invitation to create a shelf. Owner controls are omitted from visitor HTML. `view=visitor` lets an owner inspect that experience; it does not change server write authorization.

## Collections and compatibility

The original seven `FavoriteShelf` categories, picks, headline, profile URLs and preview attachments remain intact. `ShelfCollection` is a separate, additive table with its own stable slug, title, optional description, picks and presentation. Halloween, Christmas and everyday collections can coexist. Renaming a collection preserves its URL. Both models retain the five-pick limit and all six supported media types.

`users.shelf_presentation` stores the default shelf appearance. Each named collection stores its own presentation. Saved presentation takes precedence over URL preferences, so a visitor's browser storage or edited URL cannot restyle the owner's page. Legacy presentation URLs continue working until an owner saves a presentation. Existing layout/theme identifiers remain accepted, including Reading list and the approved character themes.

The migrations add `users.shelf_presentation` (JSON, non-null, default `{}`), `shelf_collections` (user foreign key with delete cascade; stable slug/title/description/picks/presentation; unique user/slug index), and `shelf_catalog_identities` (media type, SHA-256 identity key, raw provider ID; unique media-type/identity-key index). The last table supplies import mutex rows; it has no ownership or catalog-record association. They do not backfill, rewrite, rename or delete existing shelves. Use the normal migration/backup process; adding a column still requires a database schema lock. Do not roll these migrations down after people create collections without first preserving their new records and appearance settings. No production migration or deployment was performed as part of this PR.

## Catalog search

The picker retains Trove's local catalog search and adds an explicit **Search external catalog** source with a media-type filter. It reuses `/media/autocomplete`, the existing configured providers and server-signed `MetadataImport` selections. The authenticated import endpoint accepts signed selections and uses `ShelfCatalogImport` to create/find a dedicated identity mutex row, lock it in a database transaction, and resolve/create the catalog record inside that lock. Games retain `GameCatalogIdentity`. It creates catalog records without adding ownership or a personal `LibraryItem`. It never accepts unsigned title/artwork attributes. Queries remain in the field after a failed import so they can be retried.

## Story design and exports

- Gallery balances covers in a deliberate 3+2 arrangement; Feature gives the first pick hero weight; Mixtape adds restrained cover rotations while captions remain horizontal.
- Everyday, Halloween, Christmas and Midnight Feature are core palettes. Approved Telly/Facet assets and the exact bat costume remain optional under **Mascot**. No new art is generated.
- The large live preview defaults to 1080×1920. Landscape remains 1200×630. Rendering contains every artwork image, preserving portrait/square/landscape proportions.
- The design reserves generous empty space around the composition. These are conservative design defaults, not a claim of guaranteed Instagram overlay safety. Use Instagram's final composer to place link/music/sticker overlays.
- The canvas title, page title, description and alt text share the saved collection identity. Save & download persists pending selections and appearance before exporting. Copy collection link uses the actual destination. Social OG previews remain an explicit owner publication and use landscape PNGs. The renderer signature is versioned so a prior cached image cannot prevent publishing the new cover-led composition.
- Anonymous CORS requests, bounded image timeouts and image-error fallback prevent remote artwork from tainting the download canvas. Failed artwork retains the named caption.

## Verification

Request regressions cover ownership, guest visibility, persistence, independent collections, stable identity and signed catalog imports. JavaScript checks cover geometry, contrast, remote-image fallback and aspect ratio. Browser regressions exercise actual canvas PNG encoding and a downloaded PNG, all three layouts, mixed ratios, a missing cover, long titles, saved visitor presentation, and desktop/tablet/phone widths. A simulated touch on the phone viewport also switches the format and verifies the resulting canvas dimensions. CI retains browser screenshot and PNG evidence under `trove-responsive-ui`.

## Deferred optional enhancements

An optional sticker-space overlay guide, a separate hero-pick chooser (reordering already chooses the first pick), additional palette packs, and direct Instagram publishing are outside this delivery. The current work does not send collections to a social network or make engagement guarantees. These can be specified as later small personal-project items; they do not block the core owner/visitor and Story fixes.

## Import concurrency and provider assumptions

The new unique index is on the empty identity-lock table, not on any existing catalog `api_id` column. Concurrent requests through `ShelfCatalogImport` use the same lock for the same media type and normalized provider ID. PostgreSQL uses a row lock; SQLite retries its whole import transaction after a competing writer causes a busy error (up to three retries). A two-connection regression checks that simultaneous imports return one catalog ID and create one record/identity row.

Existing catalog duplicates are retained; the importer deterministically reuses the lowest existing record ID. It neither merges nor edits those duplicate records. IDs are supplied by the verified search result, trimmed and scoped by media type. Existing source conventions must remain stable: for example TMDB movie numeric IDs, TVmaze show numeric IDs, and prefixed iTunes/OpenLibrary/MusicBrainz/Steam/RAWG IDs. Different providers/aliases that denote the same creative work are not merged by title. Games retain their existing external-ID mapping logic. When an API ID is absent, an exact signed external URL is the fallback identity; a result with neither is rejected with a retryable selection error.

The lock guarantees apply to writers using this service. Legacy inventory/admin/manual writers do not acquire this new mutex, and catalog-wide uniqueness is intentionally not asserted. If those paths must participate in a global uniqueness guarantee, they need a separate audited integration with this service; no cleanup or uniqueness constraint over legacy rows is performed here.

## Exact rollback limitations

Prefer a code-only rollback while retaining all additive schema and data. The collection foreign key cascades on account deletion, so old code need not know the new association to delete an account. Old code can still use the original seven shelves, picks and headline, but it ignores the saved presentation and named-collection tables. A named-collection URL will fall back to the old shelf route/overview rather than display the new collection. Christmas/everyday palettes and Mixtape are unavailable in old code.

A schema rollback must occur only after stopping code/workers that access the new schema. Rolling back `20261019183000` drops the import mutex rows; catalog records remain. Rolling back `20261019181000` drops every named collection, including its slug, title, description, picks and presentation. Rolling back `20261019180000` removes saved default presentation values. Redeploying forward recreates empty schema; it does not restore that lost data. Preserve a database backup or explicit export before any such rollback. Existing legacy favorite shelves, user headlines and imported catalog records are not removed by these migrations.

The preview renderer signature changes invalidate previous cached compositions for lookup without deleting their blobs as a migration step. Until an owner uses **Publish share preview**, public social cards can use the branded fallback. A code rollback may likewise not recognize previews published with the new signature. The existing publication path can purge the prior preview for the same category/theme after attaching its replacement; do not rely on old preview attachments as a rollback backup.

For developers who already applied an earlier WIP revision of `20261019181000`, Rails will not rerun that timestamp merely because its definition changed. Refresh the local/staging collection foreign key to `ON DELETE CASCADE` (or rebuild the disposable test database from the final schema) before testing code-only rollback. Production has not run these new migrations as part of this work.
