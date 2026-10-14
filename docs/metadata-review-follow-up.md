# Metadata review follow-up

Branch: `codex/fix-metadata-review`, synced with master through PR #591.
Push each tested checkpoint to the branch's upstream so work can resume elsewhere.

## Progress

- Completed: register the missing globe icon and cover official-source rendering
  across all six parent media types (7 request examples pass; changed-file lint passes).
- Completed: batch-resolve raw child credits by provider identity, compatible kind and
  unambiguous name; preserve unknown names without writing entities during rendering.
- Completed: deduplicate legacy creator counts per work and repair the removed
  disclosure selector. All 33 focused examples (including browser system tests) pass;
  changed-file lint passes. The category query optimization already merged in #589 is preserved.
- Completed: wrap source labels, use meaningful source icons, distinguish interactive genre
  chips, enlarge touch targets, respect reduced motion, fix mobile entity filters and dark
  select arrows, allow biographies to span mobile widths, and simplify dense view logic.
- Completed: use the valid SVG chevron idea from #592 without its conflict markers;
  preserve #591's button design while restoring 44px targets and visible keyboard focus.
- Completed: remove the committed Puma log and ignore the runtime file.
- Completed: build Sass, pass 18 focused request examples and six browser system examples;
  verify all 45 desktop/mobile/dark page combinations render with no horizontal overflow
  or clipped source labels. Existing analytics CSP errors remain unrelated.
- Next: make browser regressions run in CI, modernize stale series system tests, and run
  the complete suite. Recheck narrow layouts, authenticated interactions and reduced motion.

## Verification and known baseline issues

Jules PR #590 duplicates some completed work. Its remaining identity lookup can still
fall back to a different provider ID and makes queries per identity; its deduplication test
creates graph-backed records instead of legacy ones. The fixes here cover those cases.
PR #592 contains committed merge-conflict markers in SCSS and ERB; do not merge it as-is.
The valid predecessor's disclosure-button layout already merged in #591 is preserved.

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
