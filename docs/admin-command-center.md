# Admin Command Center

`/admin` is the operational overview. Every route inherits the existing session-based administrator check, CSRF protection, and the shared admin layout. Public application layouts and assets are separate.

## Architecture

- `Admin::Overview` calculates aggregate counts with a one-minute `Rails.cache` lifetime. Catalog coverage uses one SQL union without instantiating media records. Small live queues and activity streams are bounded and preload associated labels.
- `Admin::Catalog` owns the media type registry, artwork checks, and reusable attention filters. Uploaded covers count as artwork. Checks detect missing references, not remote image failures or expected episode / issue totals.
- `/admin/attention` groups catalog gaps and links to filtered resource lists. The list filters also work with search and pagination. Episodes and issues accept parent filters.
- `/admin/search` searches titles, episode names, and member names, usernames, and emails. Queries require two characters, escape SQL wildcards, and return up to eight results per type. **Command / Control K** focuses global search. All results are ordinary keyboard-accessible links.
- Administrate still owns CRUD, field types, relationships, list sorting, and pagination. The shared views supply the admin shell, media presentation, native forms, empty states, and responsive table cards. Hotwire supplies navigation, action progress, and confirmation dialogs.
- `admin.scss` is built separately by Dart Sass. It uses the public app's local Instrument Sans / Space Grotesk fonts and respects each user's light, dark, or OS theme. Mobile navigation uses native disclosure groups rather than a modal menu.

## Workflow safeguards

Metadata provider search and fill actions share one flow, including books. The fill step preserves existing values; the existing automatic model sync may subsequently replace primary metadata or rebuild child records when a new API ID is saved. The matching screen and confirmation explain this behavior. Editing the record permits intentional replacement. Existing model callbacks may fetch additional details or child records after a new API ID is saved; those callbacks do not persist refresh outcomes or timestamps, so the UI does not claim to know them.

Moderation compares current and proposed values, highlights changed text, and requires confirmation. Approve / reject use a transaction and row lock, check the pending state, and atomically save the decision and contributor notification. Approval accepts only known metadata columns. Existing suggestions can be edited for notes, while new suggestions always enter the pending workflow.

Merges require confirmation and retain library entries, direct activities, comments, deduplicated likes, and edit suggestions. Non-conflicting episodes and comic issues move to the retained parent; conflicting child identities block the operation. A record cannot be merged into itself.

Credential fields never render stored tokens or secrets. Their forms start empty, preserve blank replacements, and provide an explicit clear-on-save checkbox. User password digests and signing keys are excluded from show / edit attributes. Free-form API options are also hidden because they may contain credentials.

## Data boundaries

Integration panels report saved configuration state, not live connectivity or successful delivery. The application has no persistent job outcome / import-progress store, separate metadata-refresh timestamps, or complete inbound ActivityPub processing. The overview states those boundaries explicitly. Community activity counts measure contributors with recorded collection activity, not login activity.

## Deployment and checks

Run the new operational-index migration and build both stylesheets:

```sh
bin/rails db:migrate
bin/rails dartsass:build
bundle exec rspec spec/requests/admin spec/queries/admin spec/system/admin_command_center_spec.rb
bundle exec rubocop
bundle exec brakeman -q -w2
bin/rails zeitwerk:check
```

System specs require compatible Chrome / ChromeDriver executables. Responsive QA covers 320, 375, 430, 768, 1024, 1280, and 1440 pixels, including the overview, attention list, media indexes / details / forms, merge, moderation, users, integrations, and search.
