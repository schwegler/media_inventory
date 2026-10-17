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

Category security review: all category names/search terms and pagination values
use named SQL binds. Model tables, attributes, category roles and sort expressions
come only from fixed allowlists; unknown category types are rejected. Regression
inputs include SQL punctuation and wildcards. No scanner warning was suppressed.
