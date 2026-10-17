# Audit refinement delivery

This branch implements the October 17 Trove audit in complete feature commits.
Rails, Turbo, the editorial tokens and server ownership/privacy checks remain
the foundation. No production fixture writes or deployment are part of validation.

## Bounded series collections

TV and comic detail pages load at most 30 children, including artwork, credits
and the current viewer's reviews. Season, search, status and page live in the
URL. A matching Turbo Frame response renders only the child collection. SQL
counts and completion subqueries describe the whole series/current pass; a
partial browser page never becomes the authoritative progress total. Searches
can explicitly include all seasons. Season/series bulk actions continue to
cover the whole requested scope, with a confirmation.

The legacy child partials and non-paginated stream contracts remain available
for integrations; paginated controls request a fresh bounded collection after
a write. Review saves retain the independent modal/child update path.

Regression evidence belongs in `spec/requests/series_pagination_spec.rb`:
1,000-child instantiation bound, URL/frame state, issue pagination, numbered
search, pass history, private reviews and post-write global counts.

## Database-backed category pages

Category browsing unions normalized credits with exact delimited legacy tokens
in SQL. Counts, media filtering, stable ordering and LIMIT/OFFSET precede model,
artwork and personal-rating loading. Only displayed identities become model
instances; names/counts remain scalars. SQLite uses a connection-local Unicode
folding function so its ASCII-only LOWER does not regress legacy names;
PostgreSQL uses LOWER. No new persisted projection or backfill is required.
Public category-hub summaries may be stale for up to one minute; filtered and
detail pages remain live. Existing Category APIs remain for compatibility.
“All credits” links explicitly select the whole catalog instead of the viewer's
library. The service accepts only fixed model/attribute maps and binds user values and pagination separately from fixed identifiers;
legacy separators, duplicate roles and polymorphic identities stay distinct.

`spec/services/category_query_spec.rb` checks page instantiation bounds,
counts, mixed/child types, legacy tokens, Unicode and wildcard escaping. PR603's
rating preloader is used when available; this branch does not duplicate it.

## Deliberate shelf previews and profile pathways

Profile owners have a direct Curate favorites action. Shelf navigation links
curation and profile customization. An empty visitor exhibition has one concise
state and all category destinations instead of 35 miniature placeholders.

Opening a shelf never renders a hidden canvas or uploads a preview. Expanding
the preview or downloading renders locally; the explicit Publish share preview
action persists the social-card image. Publishing requires saved picks, uses the
existing owner/CSRF/signature protections, restores its control on failure and
rejects detached/stale renders. The server deduplicates signature/theme previews
under the owner's lock. Existing public OG fallbacks remain until publication.
PR609's independent opener/name changes are not duplicated or overwritten.

Four dependency-free JavaScript tests exercise the actual controller's no-work
visit, explicit CSRF-protected publication, reuse, failure and stale-render paths.
Request tests cover no-write GET and duplicate publication; all seven categories,
themes, image formats and alt text remain available.

Category security review: all category names/search terms and pagination values
use named SQL binds. Model tables, attributes, category roles and sort expressions
come only from fixed allowlists; unknown category types are rejected. Regression
inputs include SQL punctuation and wildcards. No scanner warning was suppressed.

## Scoped, bounded social discovery

Friends sections use followed accounts only. If no visible friend activity is
available, the same discovery surface is explicitly labeled “around Trove.”
SQL window ranking collapses person/title lifecycle events before LIMIT, and
popularity groups normalized proxy/direct title identities before its nine-title
limit. Public fallback loads at most six distinct titles. Missing trackables
are filtered in SQL, not through an unbounded application scan.

A review requires a matching owner's public or viewer-owned LibraryItem. Direct
legacy events resolve only an eligible review entry, including when duplicate
legacy rows contain private bodies. Private ratings on non-review events stay
hidden. Signed-in dashboard responses explicitly remain private/no-store.
Service/request regression coverage includes high repetition, exact follow
scope, proxy grouping, orphan records and false/NULL/private/own review cases.

## Bounded background admission and operational visibility

The default in-process queue has one worker and at most 32 outstanding jobs;
provider search retains its separate single worker with an eight-job bound.
Delayed retries reserve capacity too. Both limits are configurable (1–128).
Saturation uses Active Job's normal enqueue-error contract; metadata, search,
artwork, portrait and import entry points restore a retryable state rather than
showing accepted work that was never queued. Admin displays running, queued and
scheduled counts, oldest age and the last failure class without arguments.

This is a memory/admission guard, not durable delivery. Restart discards queued
work and metrics; a database-backed worker remains a separate deployment decision
if delivery guarantees become necessary. No delivery guarantee is claimed for
social posting. Existing domain leases/cooldowns and explicit retry paths remain
necessary. The admission tests exercise saturation, delayed cancellation, failure
release and sanitized diagnostics with no provider requests.

## Ready-to-consume, accessible quick tracking

The dashboard renders at most six active cards, with a direct all-active-series
profile link. Counts and next candidates use SQL per selected pass instead of
instantiating all episodes, issues and entries. Available dated releases come
first, then unknown dates, then upcoming. Future cards use Expected/Upcoming and
retain early logging inside an explicit disclosure. Completion still counts the
whole pass; no release dates, provider identities or prior history are rewritten.
Numbered comic issues precede unnumbered specials, whose provider title remains
visible. Existing out-of-order continuation and wrap behavior remain covered.

Tracking controls have 44px minimum heights, contextual names and unique IDs.
Turbo card replacement restores keyboard focus to its next primary action, or
the section heading on completion. Child details provide bounded previous/next
queries and return-to-season links. HTTP(S) source links reject credentials and
unsupported schemes. Service/helper fixtures cover 1,000 entries, available/
unknown/future eligibility and special ordering; browser checks cover 390/1440px
layout, deliberate early logging, control size and duplicate IDs.

## Bounded metadata status feedback

An authenticated, owner-checked-for-games status GET reads three scalar fields
without enqueuing, creating refresh records or exposing provider URLs. Responses
are private/no-store. Explicit refreshes poll this endpoint with backoff, a
session-persisted request/retry counter, a ten-check/two-minute bound and abort on
disconnect. Ordinary visits do not poll. Only success/partial/unchanged performs
one final page update; failed/denied checks stop with an actionable message.
The existing CSRF-protected refresh POST and server cooldown/lease remain the
only authority for provider work. Request and actual-controller JavaScript tests
cover no-write status, game authorization, continuation, stopping and cancellation.
