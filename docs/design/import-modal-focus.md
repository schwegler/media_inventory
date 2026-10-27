# Preserve early focus in import dialogs

## CI evidence

PostgreSQL browser job `121897549219` in [run 40415756888](https://github.com/schwegler/media_inventory/actions/runs/40415756888), head `dae431b3`, seed `50322`, failed `import_confirmation_system_spec.rb:47` because the expected book search result was absent.

The actual `trove-responsive-ui` artifact shows an empty Title field. The connected thumbnail-fetcher controller has `currentQuery: ''`, the search stage is active, and no search fetch occurred. Its input trace places focus on `book_title` at 61.7ms, then on `modal-close` at 63.6ms, followed by window blur/focus and a return to Title. There are no console errors. This is consistent with focus being moved away while WebDriver entered the title, rather than a failed provider response.

The modal controller unconditionally scheduled focus to its first focusable control (Close) on the next animation frame. The import controller also focuses Title during initialization. A person or nested controller can therefore focus Title before the pending modal callback moves focus away again.

## Reproduction and limits

The unchanged original import file passed all five examples locally on SQLite at seed `50322`. The unchanged full 41-file PostgreSQL browser scope is reproduced on the exact failed head and seed in a separate disposable database; the final result is recorded on the draft PR. Local PostgreSQL is 14.23/macOS Chrome156, while CI uses PostgreSQL11/Linux. The exact uncontrolled CI typing failure is not being claimed as reproduced unless that run shows it.

A deterministic browser regression places focus on Title after the modal connects but before its scheduled animation frame. The unchanged controller moves focus to Close, so the regression fails. It passes with the guard. Two direct JavaScript regressions also fail before the change: retaining early Title focus and disconnecting before the queued frame. Ordinary autofocus from outside the dialog already passes.

## Narrow fix

The deferred callback focuses the first control only when the modal is still connected and focus has not already entered its dialog. Disconnect cancels a pending frame. Keyboard trapping, dialog labeling, background inertness, close behavior, opener restoration and import/search data are unchanged. No global readiness helper, sleep, retry, timeout increase, animation override, route, schema or setting is added.

Every original import assertion remains verbatim. The new browser case observes the existing modal connection marker, focuses Title before the deferred callback and then exercises the real search/result/import flow. Its observer is confined to the test and removed afterward.

Local fixed verification at seed `50322`: **12 import/modal browser examples pass on SQLite and PostgreSQL**, including all original six-media import boundary and keyboard/modal presentation checks. All **101 JavaScript tests pass**, including the three new modal-focus cases. Targeted RuboCop is clean. Exact-head CI results and any remaining failures are recorded on the draft PR without claiming the whole PR green prematurely.
