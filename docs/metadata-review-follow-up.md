# Metadata review follow-up

Branch: `codex/fix-metadata-review`, based on master after PRs #586 and #587.
Push each tested checkpoint to the branch's upstream so work can resume elsewhere.

## Progress

- Completed: register the missing globe icon and cover official-source rendering
  across all six parent media types (7 request examples pass; changed-file lint passes).
- Next: resolve raw child credits by provider identity, leaving ambiguous names unlinked;
  deduplicate legacy creator counts per work and repair the removed disclosure selector.
- Pending: wrap source labels, use meaningful source icons, distinguish interactive genre
  chips, enlarge touch targets, respect reduced motion, fix mobile entity filters and dark
  select arrows, allow biographies to span mobile widths, and simplify dense view logic.
- Pending: remove the committed Puma log, run full checks and desktop/mobile browser QA.

## Verification and known baseline issues

The initial review ran 843 examples on #586: 4 failures and 9 pending.
Three failures also occur on the base branch: stale selectors and copy in
`tv_episodes_system_spec.rb` and `tv_shows_system_spec.rb`. The fourth is the
removed nested disclosure in `metadata_entities_system_spec.rb`; fix that here.
GitHub Actions excludes system examples, so its green result is insufficient for UI changes.

The live book page `/books/193-morning-glories-vol-2-all-will-be-free-2011`
returned 500 during review. A book using an unrecognized source domain reproduces
`KeyError: key not found: "globe"` on #586 and renders successfully on the base branch.
Production logs are required to confirm the exact live record's exception.

In this cloud workspace, source `/workspace/cloud-setup/activate.sh` to use Ruby and gems.
Use isolated SQLite database URLs for tests and visual fixtures. Fresh installs should
load `db/schema.rb`: an older data migration calls current User validations before their
columns exist. No production database or live user records were changed.

Browser plugin is unavailable; use Playwright with the installed Chromium and inspect
screenshots. Keep temporary scripts, databases and evidence outside the repository.
Existing analytics scripts are blocked by the application's CSP; this predates the fixes.
