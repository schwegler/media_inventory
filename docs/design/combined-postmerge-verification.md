# Combined post-merge repair verification

## Reviewed repairs

The integration starts with the exact reviewed changes from #691 (`dae431b3`), #692 (`c7d55f7b`) and #693 (`c5a1c583`), based on master `ec430688`. They address metadata-history visit sequencing, deferred dialog autofocus, and native profile-filter input during a root view transition. Their original diagnosis documents and failed-run references remain intact.

The original uncontrolled CI failures did not all reproduce locally at their exact seeds. The modal-focus defect and profile snapshot hit-target defect have controlled before/after reproduction; the metadata trace demonstrated overlapping history visits and catalog DOM temporarily rendered under a detail URL. These distinctions are retained rather than labeling all failures as flaky.

Historical failed checks remain evidence:

- [40407951349](https://github.com/schwegler/media_inventory/actions/runs/40407951349): metadata history, SQLite seed26539.
- [40415756888](https://github.com/schwegler/media_inventory/actions/runs/40415756888): import result and profile filtering, PostgreSQL seed50322.
- [40418833773](https://github.com/schwegler/media_inventory/actions/runs/40418833773): metadata history on the separately reviewed profile branch, PostgreSQL seed15791.
- Original profile failure and reproduction details remain in `docs/profile-progress.md`.

## Additional integration findings

Combining only those three repairs produced local head `f6063d12`. Its eight-file focused PostgreSQL scope passed 41 examples at each of seeds26539,50322,15791,10323; its full PostgreSQL scope at seed10323 passed112 examples. The same focused SQLite scope at seed26539 failed two shelf examples: a Chrome detached-node visibility error during navigation, and a login success assertion that read the old login document while the profile response arrived. These failures and their artifacts were preserved. The remaining old-head matrix was explicitly interrupted after additional repairs became necessary. Its unfinished PostgreSQL50322 run had also recorded the same detached-node shelf error at a public-shelves destination; that artifact is retained, and the incomplete run is not counted as a pass.

The shelves worker independently reproduced the detached-node error in an original shelf-only run, locating it immediately after a workspace link navigation. The scoped repair `53ef4d0b` adds destination/readiness preconditions before the unchanged visible shelf assertions. Original repeats were four passes/one failure; five fixed repeats passed, with no exception rescue or retry.

An independent combined trace also failed an import-save success assertion after the save had succeeded: the assertion queried old confirmation DOM while the destination page/flash arrived. The integration therefore checks the completed book detail destination before the unchanged success assertion. The shared login helper checks that the login form is gone and the destination document/transition is settled before its unchanged visible success assertion. The RackTest path avoids unsupported transition pseudo-classes.

The first candidate with those additions passed shelf/login/import checks but exposed a presentation focus assertion reading BODY after Escape, with a fresh catalog document in the artifact. Its isolated lifecycle/focus trace passed and showed correct synchronous Escape focus restoration; the exact uncontrolled cause remains uncertain. The presentation example now requires the catalog destination to be complete before starting its original native keyboard sequence. The original focus assertions remain unchanged; dropdown product code is untouched.

The next exact-head candidate (`1043060b`) passed PostgreSQL focused seed26539 but failed the SQLite owner clipboard-fallback example: it attempted the copy action before requiring a completed profile document and live link-share controller. The artifact retained no pointer events, so interception is not claimed. The shelves worker supplied a seven-line profile precondition before the unchanged clipboard override/click/fallback/status/focus assertions; its focused profile tests passed. The prior failed candidate and all artifacts remain separate evidence.

## Verification contract

Only the reviewed modal-focus callback changes production behavior. The additional changes require the intended destination and completed document/transition before original assertions and actions. There are no sleeps, action retries, error rescues, timeout increases, forced clicks, animation overrides or removed assertions. Existing strict media-section/header assertions remain unchanged.

The final matrix uses separate worktrees/storage and disposable databases. It covers the eight-file combined focused scope on PostgreSQL and SQLite at all four requested seeds, plus the full CI browser scope in each original failure's database/seed combination: SQLite26539; PostgreSQL50322,15791,10323. Each result records its exact commit, seed, database, command, log and retained artifacts. Final matrix and exact-head CI outcomes are recorded on consolidated draft #691; earlier failed runs are not rerun or relabeled.

Local PostgreSQL14.23/macOS Chrome156 differs from CI PostgreSQL11/Linux. The historical uncontrolled failures and browser-driver detached-node behavior are not claimed universally eliminated by a finite passing matrix. No PR merge, deployment, production migration, privacy-setting or grant change is performed by this work.
