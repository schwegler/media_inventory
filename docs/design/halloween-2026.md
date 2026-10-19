# Halloween 2026

The invitation is Facet wearing a bat costume, floating over the existing page after a short delay. No hero, promotional paragraph or reserved stage is added. The tiny hover title is “make it weird”; activation announces “well. it’s haunted now.” and announces Undo in the header Appearance menu. No controls panel opens automatically; dismissal leaves the theme on. Dark ink-purple surfaces, orange light, moon, silhouettes and drifting mist provide the camp atmosphere. Motion uses only CSS transform/opacity. See [the shared contract](seasonal-contract-v2.md) for preferences, accessibility and the explicit UTC expiry.

Account accent, profile accent/header and shelf palette remain independently selectable. Activating the character changes browser appearance only; Undo restores the exact previous root state. Existing saved user choices, uploaded banners and catalog history are preserved.

Facet's bat PNG is an identity-preserving imagegen edit of the existing `public/brand/facet_pose_03_crate_digger.png`, retained as a detailed transparent PNG. Optimized production art is `app/assets/images/brand/facet_bat_costume_2026.png`; full source is in `docs/design/assets`. Existing `facet_pose_01_bookworm.png` and `mascot_duo_telly_and_facet_transparent.png` provide the new Facet and Telly shelf companions through technical trim/crop/resize, without simplified replacement drawings. All decorative images have empty alt text.

Story exports use the production canvas renderer with explicitly synthetic demo jackets. The three layouts are selectable; no single replacement was imposed. See [shelf export review](shelf-social-review.md).

## Current review evidence

- `docs/screenshots/halloween/facet-hover-activation.gif`: actual isolated Chrome hover and click activation, captured from the rendered app; not a mocked animation.
- `halloween-desktop.png`, `halloween-mobile.png`, `invitation-desktop.png`: current floating overlay and dark atmosphere.
- `stories/story-*.png`: native 1080×1920 exports from production renderer with clearly synthetic jackets; `story-layout-comparison.png` compares the three five-cover layouts.
- `shelf-telly-story-*.png`: actual shelf controls and Story preview at desktop/mobile widths.

Local verification: 901 nonbrowser examples passed, nine existing pending; 22 JavaScript tests passed; nine focused browser examples passed; 567 Ruby files linted clean; asset build passed; Brakeman reported zero warnings. Capture additionally checked reduced motion, Pause, Hide atmosphere, no horizontal mobile overflow and separation from navigation. CI remains the final cross-platform check.
