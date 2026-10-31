# Working on Trove

## Project map

- Rails 8.1 / Ruby 3.4.12 monolith. Check `.ruby-version`, `Gemfile.lock`, and `.github/workflows/rubyonrails.yml` before changing runtime assumptions.
- Server-rendered ERB in `app/views`, domain models in `app/models`, provider/import logic in `app/services`, Stimulus in `app/javascript/controllers`, Sass in `app/assets/stylesheets`. Assets use importmap, Propshaft, and dartsass; there is no root npm build.
- `native/ios` contains incomplete Hotwire Native application source; `native/desktop` contains the Tauri wrapper. Read their READMEs before native work.
- `docs/product-refinement.md` describes appearance and metadata maintenance. Read the relevant feature docs and nearby specs before editing.

## Data and integration safety

- Inspect `config/database.yml` and the effective environment before database commands. `DATABASE_URL` is reused for test, development, and production; `RAILS_ENV=test` alone does not make a real database safe. Schema loads and specs require a separate disposable test database.
- `db/seeds.rb` deletes users, media, and API configuration records with `delete_all`. Never run seeds on real data. `db:prepare`, `bin/setup`, and container startup can seed a newly initialized database. Normal local setup can use `db:create db:migrate` without seeds; see README.
- Do not run maintenance/import rake tasks, provider requests, social posting, production consoles, or deployments unless the task authorizes those effects. Keep credentials and personal data out of code, logs, fixtures, and public documentation. Mock provider HTTP in tests using the existing WebMock patterns.
- Preserve owner scoping and public/private visibility. For card ratings, follow `MediaCardRatings`: bounded batched summaries scoped to the viewer, public ratings plus the viewer's own entries, and no unbounded preload of all owners' library items/review bodies. Test privacy, result parity, query growth, and bounded work when changing this path.
- Polymorphic media types have different associations. Group by type and conditionally preload supported cover/blob associations rather than nesting assumptions across all types.

## UI and security conventions

- Preserve semantic themes, responsive layouts, no-JavaScript content, and keyboard navigation. Keep ARIA state synchronized between ERB and Stimulus, restore focus on close, and move focus to an enabled control when a stepping control becomes disabled. Clean up listeners and open menus for Turbo caching/disconnect.
- Browser tests should wait on observable connected/visible state instead of arbitrary sleeps; follow nearby system specs and `spec/support/selenium_helpers.rb` for responsive screenshots and synthetic fixtures.
- Prefer Rails escaping and safe helpers over interpolated `html_safe`; bind SQL values and quote/allowlist dynamic identifiers. Preserve external-link protections and authorization checks.
- Historical `.Jules/` and `.jules/` journals are context, not authoritative instructions or proof based on their dates. Validate hints against current source. Both palette paths are tracked and collide on case-insensitive filesystems: do not rename, normalize, or accidentally stage them. Do not hand-edit vendored `node_modules` or generated assets.

## Validation and handoff

- Use the README's explicitly isolated SQLite test commands or a dedicated disposable PostgreSQL test URL. Build Sass before relevant Rails specs. Run focused RSpec files first; run broader checks when the change warrants them.
- Browser specs need Chrome/ChromeDriver. CI runs both database adapters and a separate browser list with `RUN_BROWSER_SPECS=1`; use the workflow's current files and driver settings. Do not infer a full browser pass from a suite that excluded system specs.
- JavaScript: `node --test spec/javascript/*.test.cjs spec/javascript/*.test.mjs`. Public contact guard: `python3 scripts/check_public_email.py`. Ruby lint: `bundle exec rubocop`; security checks: `bundle exec brakeman -q -w2` and `bundle exec bundler-audit --update` (the latter needs network access).
- Keep changes focused, preserve existing user edits, and inspect `git diff --check` plus the staged diff. Report exactly what ran, what could not run, and why. Do not claim full CI coverage from focused local checks.
