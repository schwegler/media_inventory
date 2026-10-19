# Shelf discovery and sharing

Visitors see populated categories and collections, the saved title and presentation, intact covers, profile context, and a modest invitation to create a shelf. Owner controls are omitted from visitor HTML. `view=visitor` lets an owner inspect that experience; it does not change server write authorization.

## Collections and compatibility

The original seven `FavoriteShelf` categories, picks, headline, profile URLs and preview attachments remain intact. `ShelfCollection` is a separate, additive table with its own stable slug, title, optional description, picks and presentation. Halloween, Christmas and everyday collections can coexist. Renaming a collection preserves its URL. Both models retain the five-pick limit and all six supported media types.

`users.shelf_presentation` stores the default shelf appearance. Each named collection stores its own presentation. Saved presentation takes precedence over URL preferences, so a visitor's browser storage or edited URL cannot restyle the owner's page. Legacy presentation URLs continue working until an owner saves a presentation. Existing layout/theme identifiers remain accepted, including Reading list and the approved character themes.

The migrations add a JSON column and a new indexed table with a foreign key. They do not backfill, rewrite, rename or delete existing shelves. Use the normal migration/backup process; adding a column still requires a database schema lock. Do not roll these migrations down after people create collections without first preserving their new records and appearance settings. No production migration or deployment was performed as part of this PR.

## Catalog search

The picker retains Trove's local catalog search and adds an explicit **Search external catalog** source with a media-type filter. It reuses `/media/autocomplete`, the existing configured providers and server-signed `MetadataImport` selections. The authenticated import endpoint accepts signed selections, resolves provider IDs (and `GameCatalogIdentity` for games), and creates catalog records without adding ownership or a personal `LibraryItem`. It never accepts unsigned title/artwork attributes. Queries remain in the field after a failed import so they can be retried.

## Story design and exports

- Gallery balances covers in a deliberate 3+2 arrangement; Feature gives the first pick hero weight; Mixtape adds restrained cover rotations while captions remain horizontal.
- Everyday, Halloween, Christmas and Midnight Feature are core palettes. Approved Telly/Facet assets and the exact bat costume remain optional under **Mascot**. No new art is generated.
- The large live preview defaults to 1080×1920. Landscape remains 1200×630. Rendering contains every artwork image, preserving portrait/square/landscape proportions.
- The design reserves generous empty space around the composition. These are conservative design defaults, not a claim of guaranteed Instagram overlay safety. Use Instagram's final composer to place link/music/sticker overlays.
- The canvas title, page title, description and alt text share the saved collection identity. Save & download persists pending selections and appearance before exporting. Copy collection link uses the actual destination. Social OG previews remain an explicit owner publication and use landscape PNGs.
- Anonymous CORS requests, bounded image timeouts and image-error fallback prevent remote artwork from tainting the download canvas. Failed artwork retains the named caption.

## Verification

Request regressions cover ownership, guest visibility, persistence, independent collections, stable identity and signed catalog imports. JavaScript checks cover geometry, contrast, remote-image fallback and aspect ratio. Browser regressions exercise actual canvas PNG encoding and a downloaded PNG, all three layouts, mixed ratios, a missing cover, long titles, saved visitor presentation, and desktop/tablet/phone widths. CI retains browser screenshot and PNG evidence under `trove-responsive-ui`.

## Deferred optional enhancements

An optional sticker-space overlay guide, a separate hero-pick chooser (reordering already chooses the first pick), additional palette packs, and direct Instagram publishing are outside this delivery. The current work does not send collections to a social network or make engagement guarantees. These can be specified as later small personal-project items; they do not block the core owner/visitor and Story fixes.
