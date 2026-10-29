# Album track retrieval investigation

The initial evidence below was captured read-only on 2026-10-26. This code
change performs no production data repair.

## Reproduced cases

- Public `/albums/17-3d-country-2023` links to MusicBrainz release group
  `c0a0a417-6aac-4a75-b34a-62f7c150fef4`, a **Single**. Trove's two songs
  (3D Country, Cowboy Nudes) exactly match release
  `5b5c716f-8a4a-4aa4-a39c-f0c93dcf2be7`. MusicBrainz search returns this group
  before the separate Album group `d87d8f5d-4d89-45e1-b86d-2f9241db0edc`.
  This is a source identity error, not evidence that nine tracks disappeared.
- The album group's first returned release, `b80f279a-38f7-4695-a204-7edf24bc8cbe`,
  contains 23 tracks on three discs. Official release
  `b5a2c004-d5dc-4e61-9d5c-387671ef7d93` contains 11. Group ordering cannot be
  used as an edition identity. Both complete payloads are retained as fixtures.
- Public `/albums/5-magazine-1998` has no displayed tracks. Its source link is
  Apple album `21296483`; `/lookup?id=21296483&entity=song&limit=200` returns
  one matching collection declaring 11 tracks and all 11 song rows.
- Public `/albums/4-skeletal-lamping-2008` currently displays 15 tracks and links
  to MusicBrainz group `7a4b3792-94c6-3da8-90d9-dd45fb2aef56`. Its fresh group
  lookup returned HTTP 503; no source completeness conclusion was drawn and it
  was not repeatedly queried.
- The historical Geese test ID `1677353916` currently returns an empty iTunes
  result set. The test's generated eleven rows were not a recorded provider
  fixture and cannot establish the current provider identity.

Public pages were read at `https://media-inventory.fly.dev`; their canonical
share links use `https://trove.schweg.xyz`. Provider payload fixtures live in
`spec/fixtures/album_metadata`. MusicBrainz search used
`releasegroup:"3D Country" AND artist:Geese`; group lookup used
`inc=artist-credits+genres+releases`, and full release lookups used the include
list in `MetadataProvider#musicbrainz_includes`. The single verification used
`inc=recordings`. All provider reads used existing public endpoints.

## Path trace and causes

1. `MediaSearchService` searches iTunes album collections and MusicBrainz release
   groups. Previously it accepted Singles as albums. Search data contains no full
   track listing. `MetadataImport.preview` deliberately uses `include_children:
   false`, so confirmation is also not a track lookup.
2. Signed inventory/discovery imports pass through `MetadataImport` and
   `InventoryController`, serialized by `ShelfCatalogImport.synchronize`.
   `ShelfCatalogImport.call` also creates catalog entries for shelf selections,
   without creating library entries. Existing identities reuse existing catalog
   records. Administrate and direct service/model creation bypass the inventory
   controller. Seeds are direct model creation; there is no album bulk-import job.
3. The legacy Album callback fetched MusicBrainz group scalar fields only and
   skipped signed/shelf imports (`importing_metadata`). iTunes had no model track
   fetch. Only the inventory controller enqueued initial full metadata.
4. `MetadataRefresher.enqueue` shares a 20-second per-user cooldown and five-minute
   per-item cooldown with explicit metadata refresh. A recently requested item
   can prevent another newly created album's job from being enqueued. The normal
   production adapter is `BoundedAsyncAdapter`: one worker, bounded admission,
   volatile pending/scheduled state. Saturation rejects jobs; process exit loses
   accepted jobs. It does not provide durable automatic retries. There is no
   evidence proving which of these historical paths affected Magazine.
5. Refresh jobs and explicit refresh both use `MetadataProvider`. MusicBrainz
   group lookup formerly selected the first release, then performed full release
   lookup. A group without releases, missing media or missing track rows could
   finish as success/unchanged. iTunes requests up to 200 songs; its old fallback
   could treat the first result as the album without verifying collection ID.
6. `AlbumMetadata.reconcile` formerly matched by provider ID **or position**, then
   rewrote populated fields and provider IDs. Edition changes could therefore
   rewrite identities/order and user edits. This is unsafe for existing good lists.
7. Provider HTTP bodies are cached for seven days. Explicit refresh revalidates
   bodies; malformed JSON/error responses are not cached. Search has its own
   short-lived caches. There is no basis for diagnosing stale cache as the cause
   of the observed public cases. `MetadataMaintenance.enrich` is an explicit
   operator path and uses the same refresher; it was not executed.

## Scoped correction

Album create/API-ID commit callbacks now perform the full bounded metadata lookup
for manual, signed, shelf, admin and service imports. Album explicit refresh also
runs directly after claiming its existing lease. This removes album tracks from
the volatile queue. Mandatory initial hydration has no requesting-user cooldown,
while per-item cooldowns and leases still apply. Explicit refresh still checks
both the existing per-user and per-item cooldowns. No durable queue, scheduler,
migration or production maintenance command is introduced. Failed/partial imports remain visible and need an explicit retry;
there is no promise of automatic eventual completion after process termination.

The tradeoff is provider latency in the request: a 12-second album metadata
budget applies to both the HTTP deadline and the outer provider timeout, with
shorter per-HTTP timeouts. A process interrupted after commit can leave a stale refreshing lease; the existing status and retry path
recovers it. Background cover jobs remain unchanged.

Album search excludes MusicBrainz Singles. Unpinned groups now resolve only when
one distinct official release is reported; competing or unverified candidates
require a verified edition. See [edition ambiguity](musicbrainz-edition-selection.md).
Explicit release URLs retain that edition. Subsequent refreshes keep
the pinned release even if the group's response order or contents change. Legacy
bare/namespaced MusicBrainz IDs default to group lookup unless the stored URL
explicitly identifies a release.

Completeness uses collection/disc counts, provider identities and numbering.
Malformed/ambiguous lists do not create guessed positions. Known partial lists
can add supplied rows but cannot clear existing ones. Conflicting editions abort
reconciliation and show an explicit conflict. Existing populated track fields are
conservatively preserved because historical track field provenance is absent.

Remaining provider limits: iTunes's 200-song bound and default US storefront,
MusicBrainz's one-request-per-second policy and potentially limited embedded
release candidates. No alternate provider/region or edition is silently substituted
on failure. An unambiguous or explicitly pinned edition is a source identity,
not a claim
that it matches a listener's particular physical pressing. Group/release requests
are separated by the existing MusicBrainz delay; 429/503/timeouts remain retryable
states rather than initiating a bulk retry storm.

## Separately reviewed recovery plan (not executed)

1. Build a read-only candidate report with album ID, provider identity/URL, track
   count, disc counts, refresh state, pinned release and existing IDs. Snapshot
   complete track rows and associated personal/library history before proposing
   changes. Do not infer an incomplete album merely from a small count.
2. Classify candidates as missing data, incomplete response, wrong source identity,
   edition conflict or already correct. Fetch one rate-limited source payload per
   candidate, retain it as evidence, and show a proposed row-level diff. Confirm
   edition/region before proposing replacements.
3. Magazine is a candidate for an additive import from its existing identity.
   Geese requires an explicit identity/edition decision: never overwrite the
   existing two-track single or silently reassign its track IDs to album songs.
   A reviewer must choose whether to retain the single and add/link the album or
   approve an in-place correction with an explicit personal-history mapping.
   Skeletal Lamping should remain unchanged absent further evidence.
4. Obtain separate approval for the exact candidate IDs and changes. Apply any
   approved additive repairs in small resumable batches; stop on rate limiting,
   mismatched identity or an unexpected diff. Verify counts, IDs, ordering, user
   edits, reviews and history afterwards. Roll back only newly introduced rows or
   specifically approved field changes from the snapshot; never delete personal
   activity as a rollback strategy.

## Supported post-deploy dry-run command

After the fix is actually deployed, the first live operation is **read-only**:

```sh
DRY_RUN=1 IDS=4,5,17 LIMIT=3 AFTER_ID=0 bundle exec rake metadata:audit_album_tracks > album-track-audit.jsonl
```

This is a proposed initial **audit scope**, not an approved write scope. The command
requires explicit positive IDs, defaults to dry-run, accepts limits 1..50 (default
10), and refuses `DRY_RUN=0`. It cannot apply changes. It has not been executed
against production. Run only one audit process, using the existing deployment's
normal environment; no additional credentials or grants are required.

Each JSONL row contains the existing source/track snapshot, its SHA-256 digest,
provider rows and their digest, the pinned release ID, classification, source
completeness, safe additive candidates and a checkpoint. It does not export
personal library reviews or history. Classifications distinguish `missing`,
`partial`, `already_complete`, `wrong_edition`, `user_modified_or_unverified` and
unsupported/unknown records. Without historical per-track field provenance, a
provider difference cannot prove a manual edit; it is conservatively excluded
from proposed repairs. Source Singles and conflicting identities require review,
never automatic title matching. The report's candidates are **not approval**.

Calls run serially with 1.1 seconds between albums, plus the existing MusicBrainz
group/release spacing. Each provider operation has a 12-second budget. A partial,
unavailable, throttled or failed source stops the run without advancing that ID's
checkpoint. Resume the same explicit list with the last `checkpoint_after_id`
after provider backoff (at least five minutes for a busy source); do not loop on
failures. If a provider stays unavailable, record that target as deferred and
review a reduced explicit audit list. Repeated audits change no catalog or
library rows and produce comparable evidence digests.

After reviewing the report, approve exact IDs, unchanged source identities and
expected additions. Recheck snapshot/source digests immediately before any write;
stop and regenerate the report if either changed. The existing supported
single-record repair path is the conservative metadata refresher, for example:

```sh
TYPE=Album ID=5 LIMIT=1 USER_ID=<approved-existing-operator-id> FORCE=1 INTERVAL=21 bundle exec rake metadata:enrich
```

This example is a **future write operation**, not permission to execute it.
Use it only for an approved missing/partial target after taking a database backup
and row-level before snapshots. It retains normal user/item cooldowns, does not
change source identity, preserves populated track fields, and is idempotent under
repeated reconciliation. Do not use it for Geese or any wrong-edition/unverified
candidate. This command and code change grant no live write authority; targeted data
repairs require their own separately reviewed approval.

Keep the dry-run report, source payload evidence, approval, backup reference,
operator/time, exact command, refresh result and post-run audit together. Compare
track IDs and all associated library/activity rows before and after. For rollback,
restore only fields that the approved repair filled or rows it added, and only
when their post-repair snapshots are still unchanged and there are no new
personal references. Otherwise stop for review. Never restore a whole old album
over later user edits or delete personal activity. Wrong-edition corrections need
a separate externally verified source/edition/track mapping and explicit approval.

Unrelated validation debt: `RememberedDevice`'s absolute-expiry spec fails across
the local system DST boundary on unchanged master `227624c5` (one-hour difference)
and passes all six examples with `TZ=UTC`. No remembered-device code or tests are
changed here. UTC validation matches the CI host timezone; the default-local
baseline failure remains reported rather than hidden or excluded.
