# Metadata history readiness after merge

## Observed failure and exact-seed baseline

Master run [40407951349](https://github.com/schwegler/media_inventory/actions/runs/40407951349), commit `ec430688`, failed the SQLite metadata history example at its second Forward traversal (`media_metadata_tabs_system_spec.rb:98`, original line 120), seed `26539`.

The downloaded `trove-responsive-ui-sqlite` artifact contains a movie-detail URL but catalog DOM, with no `#title-details` or metadata controller. The screenshot visibly shows the catalog card; there are no browser-console errors. This differs from an incorrect selected tab or expanded metadata state.

The complete, unmodified 41-file SQLite browser scope was run locally at exactly seed `26539`: **111 examples, 0 failures**. The unmodified isolated example also passed five runs. The stuck CI failure therefore did not reproduce locally; it is not being dismissed or claimed as a deterministic local reproduction.

## Traced navigation ordering

Turbo changes history/location before completing the DOM render. The example previously asserted the catalog URL, then immediately issued another Back/Forward command. A test-only probe used Turbo's public `turbo:before-render`/resume interface to defer catalog rendering by 500ms and recorded lifecycle events across reload. The original example still passed locally, but exposed the unsafe ordering and the same intermediate URL/DOM mismatch found in the CI artifact:

| Original probe, relative ms | Event |
| --- | --- |
| 4142 | Catalog `turbo:before-render` begins |
| 4155 | Next Forward changes the URL to the movie detail before that catalog render finishes |
| 4656 | Pending catalog render installs catalog DOM under the detail URL |
| 4684 | Detail render eventually recovers locally |

With the stricter assertions:

| Fixed probe, relative ms | Event |
| --- | --- |
| 4826 | Catalog `turbo:before-render` begins |
| 5337 | Catalog DOM is rendered |
| 5595 | Catalog `turbo:load` completes |
| 5711 | Only then does the next Forward traversal begin |

The probe and its render deferral are diagnostic only and are not shipped. They demonstrate an under-synchronized test sequence; they do not establish that all rapid-history behavior inside Turbo is fixed.

## Focused change and validation

The example now checks rendered Movies catalog content under a non-busy, non-preview document before each subsequent history traversal. Its metadata readiness helper likewise requires a settled document and a live Stimulus controller. Every original URL, compact/expanded, content-count, Back/Forward and reload assertion remains. There are no sleeps, action retries, timeout increases, skipped assertions, disabled transitions or production-code changes.

The focused metadata/document-anchor/header suite passes **19 examples** at seed `26539`; targeted RuboCop is clean. The original strict anchor and header spec files are unchanged. The complete fixed SQLite browser scope is also rerun with the same 41 files and seed; final results are recorded on the draft PR along with exact-head CI.

## Read-only production verification

PR #689 is merged as `ec430688`. GitHub records a successful production deployment for that SHA. An isolated anonymous browser verified that the deployed page contains the new history-entry state and opens compactly on cold load, a fresh Turbo revisit after explicitly choosing Show all, and reload. The explicit Show all action still expands locally. No production content, tracking, review or privacy state was changed.
