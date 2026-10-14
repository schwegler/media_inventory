# taco ’bout it × Trove — Redesign Implementation Tracking

**Reference Authority:** `revision_2/REDESIGN_PROPOSAL.md` (Design Authority) & `revision_2/FEATURE_PRESERVATION.csv` (Capability Preservation Register).  
**Repository Scope:** `schwegler/media_inventory` (Trove Rails 8 Application).  
**Sister Site Scope:** `schwegler/tacobout.online` (WordPress Theme & Integration).  
**Baseline Verified:** RSpec request/model suite passing (537 examples, 0 failures).

---

## 1. Modular Implementation Plan

This plan organizes the redesign into self-contained, reviewable slices. Each modular slice includes code changes, tests, and a dedicated git commit.

| Phase / Module | Description | Key Deliverables & Evidence | Status |
| :--- | :--- | :--- | :--- |
| **0. Tracking & Git Hygiene** | Set up tracking register and workspace build ignore rules | `docs/REDESIGN_IMPLEMENTATION_TRACKING.md`, `.gitignore` | `DONE` |
| **1. Foundation & Assets** | Palette tokens, typography, `.mascot-sticker` system, Facet mascot PNGs, Trove app icon & favicon | `app/assets/stylesheets/_tokens.scss`, `app/assets/images/brand/*`, `public/favicon.svg`, asset specs | `DONE` |
| **2. Global Shell & Brand** | Trove faceted prism logo in navbar, companion link to `tacobout.online`, header navigation offsets | `app/views/shared/_site_navigation.html.erb`, `app/assets/stylesheets/_site_header.scss`, navigation specs | `DONE` |
| **3. Public Home & Companion Bridge** | "A home for every story, album, and game you're into", 6-format hero, "The Vault. The Broadcast." companion card, logged-out vs member dashboard separation | `app/views/landing/index.html.erb`, `app/assets/stylesheets/_dashboard.scss`, landing specs | `DONE` |
| **4. Authentication Polish** | `/login` ("Unlock Your Media Vault" + `facet_pose_04_five_star.png`), `/signup` ("Claim Your Shelf in Trove" + `facet_pose_01_bookworm.png`), Fediverse sign-in visibility | `app/views/sessions/new.html.erb`, `app/views/users/new.html.erb`, session/signup request specs | `DONE` |
| **5. Empty States & Zero-Match** | Empty filter / 0-matches card with `facet_pose_02_gamer_mode.png`, consolidated `Log a Title` and `Reset Filters`, empty library card | `app/views/shared/_empty_state.html.erb`, `app/views/video_games/index.html.erb`, catalog specs | `DONE` |
| **6. User Profile & Library Mix** | Profile header with `facet_pose_03_crate_digger.png`, visual horizontal bar breakdown for 6 media formats, dynamic Cataloging since date | `app/views/users/show.html.erb`, `_profile.scss`, profile library mix request specs | `DONE` |
| **7. Media Detail & Disclosure Shell** | Unified disclosure component for episodes & issues, genre pills vs navigation chips, credit alignment | `app/views/shared/_series_entry.html.erb`, `_media_detail.scss`, detail specs | `DONE` |
| **8. Games Dedicated Workspace** | Preserve 6-section workspace (Overview, My copies, Playthroughs, Sessions & journal, Artwork, Import/export) | `docs/video-game-tlc.md`, game workspace controllers/views, regression specs | `DONE` |
| **9. Public Reviews API Contract** | Revalidation and ETag caching semantics for `/api/reviews` | `docs/public-reviews-api.md`, `app/controllers/public_reviews_controller.rb`, API specs | `DONE` |
| **10. Verification & Quality Gates** | Full RSpec suite, accessibility audit (WCAG 2.2 AA touch targets/contrast), responsive checks (320px–2000px) | Full test suite passes, zero broken routes | `DONE` |

---

## 2. Commit Log & Progression

- **Commit 0:** `Add redesign implementation tracking document and ignore native build artifacts`
  - Added `docs/REDESIGN_IMPLEMENTATION_TRACKING.md`.
  - Updated `.gitignore` to ignore `native/ios/MediaInventory/.build/`.
- **Commit 1:** `Establish redesign design tokens, brand palette, and mascot asset system`
  - Added official Facet mascots and Trove logos to `app/assets/images/brand/`.
  - Updated `app/assets/stylesheets/_tokens.scss` with refined color palette, spacing, and `.mascot-sticker` system.
  - Added request spec `spec/requests/brand_system_spec.rb`.
- **Commit 2:** `Integrate Trove faceted app icon into header navigation and footer branding`
  - Updated `app/views/shared/_site_navigation.html.erb` with `brand/trove_rounded_app_icon.png`.
  - Updated `_site_header.scss` with desktop and mobile logo sizing and border radius.
  - Updated `app/views/layouts/application.html.erb` footer with Trove branding and companion link.
  - Added request spec `spec/requests/global_shell_navigation_spec.rb`.
- **Commit 3:** `Redesign public landing hero, companion bridge, and 6-format onboarding`
  - Updated `app/views/landing/index.html.erb` with "A home for every story, album, and game you’re into" hero and `facet_pose_01_bookworm.png`.
  - Added companion bridge card "The Vault. The Broadcast." with duo mascot and direct link to `tacobout.online`.
  - Updated "Make it yours" onboarding steps covering all 6 formats and active seasons.
  - Updated `_editorial.scss` with responsive hero and companion card styles.
  - Added request spec `spec/requests/landing_hero_redesign_spec.rb`.
- **Commit 4:** `Redesign authentication views with Facet mascots and Fediverse emphasis`
  - Updated `/login` with "Unlock Your Media Vault" header, `facet_pose_04_five_star.png`, and "Start your vault →" signup prompt.
  - Updated `/signup` with "Claim Your Shelf in Trove" header, `facet_pose_01_bookworm.png`, and "Already archiving? Log in →" login prompt.
  - Preserved multi-tab auth container supporting Email, Bluesky, and Mastodon flows.
  - Updated `_editorial.scss` with auth header and mascot layout rules.
  - Added request spec `spec/requests/authentication_redesign_spec.rb`.
- **Commit 5:** `Implement Mascot Empty-State Cards across video games and media catalogs`
  - Added centered `.mascot-empty-card` with `facet_pose_02_gamer_mode.png` for zero-match filter views.
  - Added `.mascot-empty-card` with `facet_pose_01_bookworm.png` for empty personal collection shelves.
  - Added styles for `.mascot-empty-card`, `.empty-state-mascot`, and `.empty-state-actions` in `_editorial.scss`.
  - Added request spec `spec/requests/empty_states_redesign_spec.rb`.
- **Commit 6:** `Fix Facet mascot aspect ratio on landing page and move child card Details button`
  - Corrected `.mascot-slot-hero` sizing and added `width: auto` + `object-fit: contain` to `.mascot-sticker` to eliminate aspect-ratio squash/stretching.
  - Sized Bookworm Facet to natural 140×248 and Duo mascot to natural 197×110.
  - Replaced cramped hero flex header with balanced 2-column `.home-intro-main` grid aligning Facet harmoniously beside headline, description, and CTA buttons.
  - Moved `.series-entry-details` outside `.series-entry-row` to cleanly position the "Details" disclosure button and full-width expandable metadata body (unblocking Jules).
  - Added request spec `spec/requests/child_card_expanders_spec.rb` and updated `spec/requests/landing_hero_redesign_spec.rb`.
- **Commit 7:** `Redesign profile header with unobstructed avatar, Crate Digger companion, and horizontal library mix bars`
  - Positioned `facet_pose_03_crate_digger.png` in a dedicated `.profile-companion-mascot` element within `.library-profile-heading`, keeping the user avatar 100% clean and unobstructed.
  - Converted the plain-text Library mix list into a visual horizontal bar breakdown across all 6 formats with proportional progress fill tracks and dynamic percentages.
  - Added on-brand zero-match note for Video Games (`0 logged yet · (backlog incoming)`).
  - Computed dynamic `Cataloging since [Month Year]` from `@user.created_at` instead of hardcoding dates.
  - Added request spec `spec/requests/profile_library_mix_spec.rb`.
- **Commit 8:** `Unify episode and comic issue disclosure shell and enforce genre navigation chips`
  - Validated unified disclosure architecture for TV episodes and comic issues across `_series_entry.html.erb` and `_series_entries.scss`.
  - Enforced clear separation between "Open" links, "Mark read/watched" primary action, and the "Details" disclosure toggle with zero nested interactive element collisions.
  - Sized disclosure toggles and category pills with 44px touch targets and accessible focus-visible outlines.
  - Verified genre chips navigate to `/categories/genres/:name` while metadata features remain static pills.
  - Extended request specs in `spec/requests/child_card_expanders_spec.rb`.
- **Commit 9:** `Establish video game dedicated workspace subnavigation and verify private data boundaries`
  - Linked all 6 dedicated workspace sections in `_media_detail.html.erb`: Overview (`#overview`), My copies (`#game-copies`), Playthroughs & sessions (`#game-playthroughs`), Journal (`#game-journal`), Artwork gallery (`#game-artwork`), and Export & tools (`#game-tools`).
  - Added `#game-tools` target anchor to `app/views/video_games/_tracking.html.erb`.
  - Reinforced privacy boundaries so personal playthroughs, notes, journal entries, and milestones are strictly protected and inaccessible to other visitors.
  - Added request spec `spec/requests/game_workspace_spec.rb`.
- **Commit 10:** `Verify public reviews API contract, ETag revalidation semantics, and privacy boundaries`
  - Verified `/api/reviews` endpoint implementation against `docs/public-reviews-api.md`.
  - Enforced representation-derived ETags and `Cache-Control: public, no-cache` conditional revalidation (304 Not Modified).
  - Ensured immediate 200 payload invalidation on review edits, deletions, or visibility toggle to private (`is_public: false`).
  - All 10 API request examples in `spec/requests/public_reviews_spec.rb` confirmed passing.
- **Commit 11:** `Redesign 404 error page with Dead air on this channel copy and complete quality gate verification`
  - Redesigned `public/404.html` with on-brand styling, Bookworm Facet mascot sticker, search recovery form, and links to catalog home and sister publication.
  - Mirrored brand logo and mascot assets to `public/brand/` for standalone static error page serving.
  - Verified 404 page content and structure in `spec/requests/error_pages_spec.rb`.
  - Executed full RSpec test suite: 778 examples, 0 failures across all request, model, service, helper, and job specs with 81.6% line coverage.
- **Commit 12:** `Update Trove metadata branding, OpenGraph image fallback, and complete favicon asset suite`
  - Updated `public/favicon.svg` to feature Trove's signature violet/lavender faceted prism vector and gold crown accent.
  - Added physical `favicon.ico`, `favicon.png`, `apple-touch-icon.png`, and `icon.png` to `public/`.
  - Added light/dark `theme-color` meta tags (`#7C3AED` and `#161320`) and complete favicon link tags to `application.html.erb` and `shelf.html.erb`.
  - Enhanced Open Graph and Twitter Card description defaults covering all 6 formats and replaced SVG preview image fallback with `trove_logo_dark_card.png` in `ItemSharingHelper`.
  - Added RSpec test coverage in `spec/requests/branding_metadata_spec.rb`.

---

## 3. How to Pick Up From Where We Left Off

For any agent continuing this work:

1. Check Section 1 table above for the next module marked `TODO` or `IN PROGRESS`.
2. Review the corresponding section in `revision_2/REDESIGN_PROPOSAL.md` and rows in `revision_2/FEATURE_PRESERVATION.csv`.
3. Implement the feature and its accompanying RSpec tests.
4. Run the relevant specs:

   ```bash
   eval "$(/opt/homebrew/bin/brew shellenv)" && eval "$(rbenv init -)" && bundle exec rspec <spec_file>
   ```

5. Commit the change with a clear commit message.
6. Update the status in this document (`docs/REDESIGN_IMPLEMENTATION_TRACKING.md`).
