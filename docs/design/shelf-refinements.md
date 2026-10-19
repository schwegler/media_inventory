# Shelf refinements

The showcase is `/@username/shelf` without a category. `category=overall` is an editable favorites category, not the showcase. The prominent View shelf overview action and heading now return to the showcase; Edit selections returns to Overall. Viewing/Editing labels distinguish the two. Theme, portrait layout, texture and companion survive these links. View profile remains a separate destination.

Midnight Feature is a distinct optional shelf theme. Halloween is unchanged. Ink-black surfaces, red accents, static film grain, condensed uppercase poster headings and a scratched rule suggest a late screening without reducing cover/title legibility. Only display headings are distressed; ordinary labels and controls stay clear. The same palette and treatment render in landscape and every portrait layout, preview and downloaded PNG. Existing Telly/Facet PNGs are preserved from current master, including PR623’s updated Telly.

Grain uses CSS gradients in the shelf and a bounded deterministic set of tiny canvas marks generated only when an export is requested. There are no new assets, fonts, timers, animated filters, flashing or network requests. This treatment is static under every motion preference.

## Consolidated Appearance

The header's Appearance control is available at desktop/mobile widths, using native disclosure semantics, keyboard-operable fields, Escape/outside dismissal and 44px targets. It contains base System/Light/Dark, base accent, Halloween/Off, Undo, Pause, Hide atmosphere and Restore character. Base choices persist in this browser per viewer and are invalidated when saved account preferences change; account/profile settings remain untouched. Base choices explicitly leave the seasonal override. They never read or write shelf export theme/style keys.

Activating Facet changes the theme and announces Undo's location; it does not open a floating panel. Only the PNG and X remain over content. X preserves the active theme and closes the menu if open. The theme persists across navigation, while the character remains dismissed. Restore character keeps an already active theme. The header menu opens only on an explicit Appearance action or a click on the already active character.

Live verification before this refinement: production deployment `9eba03126fa005e603ef6e6a48b93b4df6f1a509` succeeded (Fly release 204 complete). Public `/@schwegler/shelf?category=overall&theme=electric` exposed all three portrait layouts and rendered a genuine 1080×1920 canvas. Halloween activation, exact Undo and mobile overflow checks passed. Existing analytics CSP blocks appeared; no relevant seasonal/share runtime errors were observed. New refinement work remains a PR until separately merged/deployed.

## Review evidence

`docs/screenshots/shelf-refinements/` retains actual local application captures at desktop/mobile sizes, including keyboard overview navigation, the explicit header menu, mascot-only activation, and dismissal with Halloween still active. Native `midnight-feature-portrait-*.png` and `midnight-feature-landscape-*.png` come directly from `shelf_image.js` with clearly synthetic demo jackets; no production ownership, history or ratings were invented. The comparison image orders Exhibition, Reading list, Collector’s edition left to right.

Focused verification: 19 request examples, 31 JavaScript tests and 12 browser examples passed; all 573 Ruby files linted clean and the asset build passed. Export capture independently exercised all three portrait layouts, one/three/five picks and landscape. CI checks the full suite on the PR’s final head. Telly artwork has no diff from current master.

## Approved Halloween preset

The approved screenshot is Halloween night: dark plum, orange light, moon, mist and fireflies. It is distinct from Midnight Feature. `User.seasonal_theme` persists this explicit global choice independently of existing base mode/accent and profile/shelf settings. The actual Appearance settings page and header use the same validated `off` / `halloween` field. Header writes use the authenticated settings endpoint with CSRF; guests keep browser-only choice. Failed account writes announce that the browser choice could not be saved.

Saving settings through Turbo morph refreshes the live theme and header state. No mascot is required to select or restore the full theme. Only the invitation is limited to the fixed October 2026 window; an explicitly selected account theme remains available afterward. Outside the promotion, no character is automatically invited. Dismissal leaves the theme on and restoration remains explicit.

## Atmosphere visibility

The approved dark Halloween palette remains intact. The moon has a soft warm gradient/halo, fireflies move along the outer margins rather than over text, mist drifts farther, and tree/hill layers have clearer separation. Surface panels remain about 92% opaque and inputs about 95% opaque, preserving strong foreground contrast while allowing a trace of movement behind them. Motion remains CSS transform/opacity only, with no flashing or runtime animation loop.

A genuine 24-frame browser recording on a clearly synthetic local book detail page measured changing moon/firefly/mist transforms over approximately 11.5 seconds. The mist moved about 58px and fireflies about 19px vertically during that sample. Pause and OS reduced motion both produced static computed animations. Desktop/mobile detail screenshots and the GIF are retained alongside the other review captures.


## Shared headline identity

A saved custom headline is primary on the showcase, every category page and every share-card layout. Category is secondary. Casing is preserved, including in Midnight Feature. Metadata/alt text use the same identity, and all shelf-facing copy describes selections or picks rather than claiming a top-five ranking. Existing pick storage/order and the saved headline remain unchanged.

DOM and metadata values are escaped. Canvas titles wrap within bounded geometry, with grapheme-aware truncation for long Unicode text and a safe missing-headline fallback. The preview signature version changed so an obsolete card cannot masquerade as a current headline-aware card; owners can explicitly republish their social preview using the existing action. Preview, download and publish share the same renderer.

Existing explicit v2 browser choices are recognized when the only preference change is the newly added default preset field. They retain their prior appearance/Undo snapshot and migrate to the same signed-in preset, while viewer changes or changes to base account preferences still invalidate the old override. This is a one-time explicit-choice migration, not an automatic promotion.

Final focused verification: 28 request examples, 35 JavaScript tests, 14 browser examples, a final seven-example persistence/headline pass and the targeted mobile settings capture passed. Ruby lint inspected 574 files; the final capture adjustment is lint-clean. Native cards now show the shared custom headline and category subtitle. The two real animation captures show improved atmosphere and mascot activation/dismissal without a persistent floating control panel.
