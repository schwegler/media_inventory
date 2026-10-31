# Book editions and child reviews

This change keeps a Book as the shared work and places BookEdition and BookChapter records beneath it. Existing catalog, library, review, track and chapter IDs are never replaced by metadata reconciliation. Parent ratings and finished-book/album counts remain independent of children.

## Discovery and sources

Apple US ebook and audiobook search run separately, with format labels and distinct provider IDs. Audiobooks use collectionName/collectionId/collectionViewUrl; ebooks use trackName/trackId/trackViewUrl. A failed format does not hide the successful one. HTTP responses and search results retain the existing human-triggered bounded cache/deadline behavior. No paid service is required.

Book work matching accepts a provider ID, an attached edition ID, or one exact title-and-author match. It never uses search ranking as identity. Ambiguous existing works require selecting a catalog result. Existing duplicate records are preserved. Reimporting an edition is idempotent. Selecting Witchwolf audio can attach the edition to a manually added Witchwolf work; it cannot replace the work's date, identity or review. Audiobook release dates live on the edition, not as an inferred work publication date. Variant titles/author spellings may require selecting the existing catalog work rather than automatic matching.

Open Library work refresh no longer takes an arbitrary first edition as the user's edition. An explicit `/books/OL…M` identifier still supplies that edition's bibliographic facts. Search requests ISBN and edition identifiers for future verified selection. We do not infer chapter lists from these identifiers, Google Books previews, or audiobook track counts.

### Provider check, 2026-10-31

Read-only US searches used title plus author, Apple limit 25, Open Library title/author limit 5. This small availability check does not establish comprehensive coverage or superiority; raw result counts include related works and alternate editions. Observed candidates:

| Query | Apple ebooks | Apple audiobooks | Open Library |
| --- | --- | --- | --- |
| Witchwolf / Sam Burns | No results | Correct Witchwolf by Sam Burns & W.M. Fawkes, ID 6786439611; also its sequel | No results |
| Witch Wolf / Winter Pennington | Correct title/author | Correct title/author, Kassandra Lyall edition | Correct title/author |
| Dune / Frank Herbert | Correct title/author; also bundles and adaptations | Correct title/author; also other authors' Dune works | Correct title/author; also sequels |
| Frankenstein / Mary Shelley | Multiple editions | Multiple editions | Multiple editions and variant titles |
| All Systems Red / Martha Wells | Correct title/author and related titles | Standard and dramatized editions | Correct work plus omnibus editions |

Earlier exact Apple lookup and the publisher confirmed Witchwolf's audio date of 2025-10-28. This is no evidence of an ebook. Open Library title/author search had no Witchwolf result. Google Books returned HTTP 429 daily quota and no authenticated project was available: coverage is **unknown**, so there is no Google integration or claimed coverage advantage. Hardcover requires a token and was not authenticated. ISBNdb price/licensing were not verified and no subscription was created. Amazon Creators API requires Associates eligibility, credentials, and restrictive affiliate-content handling; it remains a possible future optional adapter, not a dependency.

References: [Apple Search API](https://performance-partners.apple.com/search-api), [Open Library Books API](https://openlibrary.org/dev/docs/api/books), [Open Library API guidance](https://openlibrary.org/developers/api), [Google Books volumes](https://developers.google.com/books/docs/v1/reference/volumes), [Google Books terms](https://developers.google.com/books/terms), [Amazon Creators API](https://affiliate-program.amazon.com/creatorsapi/docs/en-us/introduction).

## Lists and progress

A user with a book in their library can add an edition and manual list, or fill an existing edition with no chapter list. Each line is either a title or `Part | Label | Title`; prologues, parts and optional titles need no invented chapter number. Literary chapters and audio segments are explicitly different structure kinds. Source and edition date/ISBN remain visible. A manual list is identified as manual; the complete-list checkbox is the submitter's assertion, not provider verification.

Existing lists cannot be replaced through this UI. To correct or change editions without destroying reviewed children, add a separate edition. The reconciliation service accepts stable identities, ignores empty/partial omissions, preserves existing facts, and rejects conflicting position identities in a transaction. It does not delete children. No automatic table-of-contents import or cross-edition chapter equivalence is claimed.

Reading/listening passes are scoped to the owner, work library entry and edition. Completion writes set an explicit desired state and are idempotent. Starting another pass uses an expected previous pass number to prevent duplicate retries. Previous passes remain visible to their owner. Unknown lists show unknown progress; partial lists show known rows, not a claimed total. Passes do not automatically finish a book or change its review/rating, and use separate tables from TV/comic passes.

## Reviews and privacy

Track pages reuse the existing AlbumTrack IDs. Chapter and track pages use the existing review modal and polymorphic LibraryItem review records. Sibling review navigation is ordered by disc/track/stable ID, edition chapter position/stable ID, TV season/episode, or comic issue order. Unknown album positions follow known positions. Navigation skips missing reviews and selects only the same author's public reviews plus that author's private reviews when viewed by the owner. Parent review pages list that author's visible children; book lists are grouped by edition. Child reviews link to the same author's visible parent review when it exists.

Visibility is rechecked on every review request with private/no-store responses. Private child review links, counts and edition-group existence do not appear to other readers. Book progress is owner-only and uncached. Public feed serialization supports child reviews and parent artwork fallback without assuming child cover attachments exist.

## Migration and rollout

`20261031060000_create_book_editions_and_reading_passes` only creates four tables, foreign keys and unique indexes. It does not backfill, rewrite, delete or reidentify existing records. Migration rollback must only be used before feature data exists; dropping these new tables later would discard edition/progress data. No deployment or production migration is part of this PR.
