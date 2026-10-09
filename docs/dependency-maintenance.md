# Dependency maintenance

Updated on October 8, 2026.

The application uses Ruby 3.4.9 and Bundler 4.0.22. Runtime versions are kept
consistent in `.ruby-version`, `Gemfile`, and `Dockerfile`. The Ruby 3.4 line
keeps this update within a supported runtime without also introducing a Ruby 4
migration. CSV is declared explicitly because Ruby 3.4 ships it as a bundled gem.

All Ruby gems have been resolved to their newest compatible stable releases.
Rails is 8.1.4. The old Psych 5.0.1 pin has been removed; Docker's build stage
installs `libyaml-dev` for native compilation.

The desktop client uses Tauri API 2.12.2 and CLI 2.12.1. Its Rust dependencies
are resolved in `native/desktop/src-tauri/Cargo.lock`. The iOS client uses
Hotwire Native 1.3.1, with a checked-in `Package.resolved`.

## Upstream constraints and remaining advisories

- Rails Active Storage requires Marcel 1.x; Marcel 2.x cannot currently resolve.
- RSpec requires diff-lcs below 2.0.
- Tauri's dependency chain pins generic-array 0.14.7 and the older TOML 0.8
  dependency family. Newer patches cannot currently resolve with those constraints.
- RustSec reports [RUSTSEC-2024-0370](https://rustsec.org/advisories/RUSTSEC-2024-0370.html)
  for unmaintained `proc-macro-error` 1.0.4, and
  [RUSTSEC-2024-0429](https://rustsec.org/advisories/RUSTSEC-2024-0429.html)
  for iterator unsoundness in `glib` 0.18.5. Tauri's Linux GTK dependencies
  require the older GLib line; the fix is in GLib 0.20 or later. These warnings
  are not suppressed, and require upstream dependency changes.
- PostgreSQL stays on the current 17-alpine image family. CI now matches the
  development and production Compose files. A major PostgreSQL upgrade needs a
  separate database-volume migration.

## Refresh and verify

```sh
bundle update
bundle exec bundler-audit check --update
bundle exec brakeman -q -w2
bundle exec rails dartsass:build
bundle exec rails zeitwerk:check
bundle exec rspec

(cd native/desktop && npm update && npm audit)
(cd native/desktop/src-tauri && cargo update && cargo check --locked && cargo audit)
(cd native/ios/MediaInventory && swift package update)
```

Build the iOS package against an iOS Simulator SDK using Xcode. Dependency
resolution alone does not compile the app's Swift bridge components.

Dependabot checks Bundler, GitHub Actions, npm, Cargo, Swift, and Docker weekly.

## Review fixes

- CI runs RSpec explicitly, includes the browser suite, waits for PostgreSQL
  readiness, and compiles both native clients on macOS.
- Installed `node_modules` packages are no longer tracked; use `npm ci` to
  reproduce the reviewed lockfile. Build artifacts are ignored.
- Staged forms focus synchronously when switching stages and stop fetching
  cover results while details are being edited.
- Browser helpers wait for the actual search controller and use native button
  clicks instead of a fixed delay and JavaScript click.
- iOS packages its path configuration and loads it from `Bundle.module` rather
  than looking for an unpackaged resource in the host app bundle.
- Unfiltered inventory parameter logging is removed. RuboCop targets Ruby 3.4,
  and its new directive-scope findings have been corrected mechanically.

## Validation results

- npm audit and Bundler Audit: no vulnerabilities found.
- Brakeman: no errors or security warnings.
- RustSec: no vulnerabilities; the two upstream warnings above remain.
- Desktop: `cargo check --locked` passes without warnings.
- iOS: package builds for the arm64 iOS 18 Simulator target with Xcode.
- Full RuboCop, Rails assets, and Zeitwerk loading checks pass.
- PostgreSQL adapter: 440 examples, 0 failures, 9 pending, using an isolated
  local PostgreSQL 14.23 instance. CI uses PostgreSQL 17.
- After rebasing onto PRs #511 and #512, all 16 provider-search and staged
  media-search examples pass, and full RuboCop remains clean.
- Browser validation is not fully green. The merged baseline with updated
  dependencies ran 478 examples with 1 browser failure and 9 pending. Browser
  reruns reproduce intermittent native Chrome input/click failures across the
  album, comic, and game creation/review flows. The final full run has
  478 examples, 1 comic-creation failure, and 9 pending. These were also observed before
  the dependency update. They are not excluded or marked pending in this PR.
- Docker build could not be run because Docker is unavailable locally.
