# MusicBrainz edition ambiguity

The read-only provider evidence captured on 2026-10-26 exposed a selection
regression in the album import policy. Skeletal Lamping group
`7a4b3792-94c6-3da8-90d9-dd45fb2aef56` contains both the full album release
`17c32c3c-0769-4009-bfc9-000501d1bf23` dated `2008-10-07` and the official
**Skeletal Lamping Bonus CD**, release `085254ac-112c-4dbf-8db6-5dcc1c4201e9`,
with five tracks and a year-only date `2008`. Sorting official releases by date
puts the bonus disc first. Replacing that sort with title matching, response order,
region preference or the largest track count would still guess an edition.

The captured release-group response is a public-provider fixture; it contains no
library records, reviews, private snapshots or repair credentials.

## Selection policy

- An explicit stored `/release/` identity continues to fetch that exact release.
- A release pin is honored only for its matching stored release-group identity.
  Changing the group cannot reuse a different group's pin.
- An unpinned group can resolve automatically only when it reports one distinct
  release with official status. Duplicate rows for the same ID are one identity.
- Multiple reported releases, or an unverified status, require a verified edition.
  No release lookup, track import or new pin occurs. Empty/missing release data
  remains a partial-provider result rather than evidence of a complete list.

The visible `edition_required` state distinguishes an unresolved edition from a
transient failure. Existing tracks and user fields remain untouched. The read-only
audit reports the same state, proposes no changes, and does not blame user edits
when it lacks an edition to compare.

This deliberately reduces automatic MusicBrainz track retrieval for ambiguous
new group imports. A title/artist/year match identifies an album, not a particular
edition. Verification must establish the release identity and exact tracklist;
recording IDs and ISRCs are relevant when mapping existing track associations.
No edition-picker UI or automatic repair of historical pins is introduced.

## Boundaries and validation

The existing 12-second provider budget, item/user refresh cooldowns, HTTP limits,
per-call MusicBrainz spacing, additive reconciliation and edition-conflict guard
remain in place. Explicit multi-disc releases and verified pins retain their
ordering and database track IDs. This change does not rank candidate dates, titles,
regions or counts and does not expand a release group with speculative requests.

Regression tests use the captured Skeletal group, reordered/full-title variants,
actual 11- and 23-track Geese releases, explicit multi-disc identities, verified
pins, missing data and unverified release status. This code change runs no live
backfill and carries no authority to merge or deploy.
