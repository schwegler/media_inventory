# Profile overview and In progress dashboard

The overview keeps two recently active titles and a single horizontal Recently collected row. The row has its own keyboard-focusable scroll region and a persistent View collection link. Collection/backlog pages keep their existing grids and management tools. The In progress tab is the full tracker, with media filters, recent/title/progress sorting, twelve titles per page, empty states and quick tracking.

## Activity semantics

- TV/comics: the latest `ConsumptionPassEntry.consumed_at` in the active pass. These entries stamp the actual watch/read action; they do not use the user-entered completion date on the episode/issue library item. A pass without entries falls back to its immutable creation timestamp.
- Games: the latest session end timestamp in the latest active playing/replaying run; an untouched run falls back to its immutable creation timestamp. A newer completed/paused/dropped run supersedes older runs. One preview per game.
- Equal activity timestamps: library item ID descending, then pass/playthrough ID descending. Title/progress sorts also have deterministic title/ID ties.
- Catalog edits, reviews, ratings, library additions and mutable `updated_at` values do not promote existing tracking activity.
- Completed, dismissed, missing and childless series are excluded before the overview limit/pagination. Next-entry release/out-of-order behavior stays in `NextSeriesEntry`.
- Books have no active reading/page-progress state in the existing model. Their existing library and finished-read actions remain available; this PR does not invent an active state from collection/backlog membership.

Counts are aggregated by media type. Only visible titles build next-entry candidates; artwork attachments are preloaded. Large episode libraries remain bounded by the existing SQL candidate selection.

## Privacy and sharing

Private game tracking remains owner-only, including games explicitly selected for the separate public game shelf. Public profile previews do not expose playthrough/session notes, percentages or counts. Visitor TV progress is independent of review/rating visibility. Comics retain their existing public-entry rule. Visitors see the current active summary (series, completed/total, progress bar and next catalog entry), without rewatch numbers, editing controls or full watch history. All profile/tracker responses are `private, no-store`, and profile pages disable Turbo DOM snapshot caching; owner/public-preview pages have `noindex, follow`. Canonical and OpenGraph URLs consistently point at the public profile without preview, pagination or filter parameters. Share/copy use that public URL; native sharing, status announcements and a selectable fallback link remain available.

The existing model treats `LibraryItem.is_public` as **review/rating visibility** on collection pages. This PR preserves that product contract (and existing privacy tests); it does not turn private reviews into hidden collection membership or change permissions. There is no private-profile/hidden-collection flag to change. Existing explicit shelf selections, profile customization, follows and social features remain intact.

## Watch-progress visibility refinement

The TV tracker previously reused the review/rating `is_public` flag. TV progress is now generally public on profile overview and In progress pages, including anonymous visitors and the owner's Public preview. A private or unset review flag continues to hide the review and rating, but does not hide the current TV progress summary. Review text, ratings, completion dates, previous passes and game/session notes are not added to the public tracker. Dismissed, completed and empty trackers remain excluded. Comics and game visibility are unchanged.

The merged TV-summary refinement includes existing active trackers whose review flag is false or unset; it does not migrate or change those review flags. There is no separate TV-progress privacy preference or private-profile flag in the current schema; this change does not reinterpret review privacy as permission to publish reviews or full histories. Public media detail pages still show only the visitor's own tracking/editing state, not another person's history.

## UI evidence and regression coverage

Screenshots in `docs/screenshots/profile-progress` use synthetic local fixtures only. Before images render the master implementation with the same fixture data. The 390px and 1440px screenshots cover overview, Recently collected before/after, dashboard and filter empty state. The dark mobile screenshot covers private game tracking.

Regression coverage includes real activity order, immutable fallback/timezone handling, deterministic ties, completion/empty exclusion, two-item selection, bounded visible-page candidate building, pagination, filters/sorting, private/public-preview behavior, cache/SEO metadata, single-row geometry, Turbo refill/counts, keyboard focus, clipboard fallback, loading/error/retry states and existing game tracking actions.

## Owner library navigation

The previously deferred [owner-library task](https://app.notion.com/p/401a99cf980e81a7a347ea376111eb47) was selected during backlog grooming. Owner Collection and Backlog pages now link into the existing category My Library workspaces through one shared format navigator. The same navigator connects all six personal workspaces, including the game workspace. Desktop, mobile and native My Library links use the owner collection overview, and the active state also recognizes personal category workspaces.

Profile shelves and their media filters remain available, including public preview. Management navigation is owner-only. Search, sort, shelves, edition/ownership filters, status, ratings, display modes, pagination, game saved views and quick tracking continue using their existing implementations; no duplicate editor or bulk operation is added to profiles. Browse/My Library switches retain compatible search/sort (and the existing catalog shelf predicate for non-game formats). Switching formats retains search and compatible title/rating/recent sort and grid/list settings, resets pagination and format-specific filters, and preserves the complete URL when choosing the current format. Browser Back restores the previous workspace URL and its filters.

No schema, authentication, review privacy, public-progress or social behavior changes are part of this navigation work. Draft PR delivery and merge/deployment remain separate outcomes.
