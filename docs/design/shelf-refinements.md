# Shelf refinements

The showcase is `/@username/shelf` without a category. `category=overall` is an editable favorites category, not the showcase. The prominent View shelf overview action and heading now return to the showcase; Edit favorites returns to Overall. Viewing/Editing labels distinguish the two. Theme, portrait layout, texture and companion survive these links. View profile remains a separate destination.

Midnight Feature is a distinct optional shelf theme. Halloween is unchanged. Ink-black surfaces, red accents, static film grain, condensed uppercase poster headings and a scratched rule suggest a late screening without reducing cover/title legibility. Only display headings are distressed; ordinary labels and controls stay clear. The same palette and treatment render in landscape and every portrait layout, preview and downloaded PNG. Existing Telly/Facet PNGs are preserved from current master, including PR623’s updated Telly.

Grain uses CSS gradients in the shelf and a bounded deterministic set of tiny canvas marks generated only when an export is requested. There are no new assets, fonts, timers, animated filters, flashing or network requests. This treatment is static under every motion preference.

## Consolidated Appearance

The header's Appearance control is available at desktop/mobile widths, using native disclosure semantics, keyboard-operable fields, Escape/outside dismissal and 44px targets. It contains base System/Light/Dark, base accent, Halloween/Off, Undo, Pause, Hide atmosphere and Restore character. Base choices persist in this browser per viewer and are invalidated when saved account preferences change; account/profile settings remain untouched. Base choices explicitly leave the seasonal override. They never read or write shelf export theme/style keys.

Activating Facet changes the theme and announces Undo's location; it does not open a floating panel. Only the PNG and X remain over content. X preserves the active theme and closes the menu if open. The theme persists across navigation, while the character remains dismissed. Restore character keeps an already active theme. The header menu opens only on an explicit Appearance action or a click on the already active character.

Live verification before this refinement: production deployment `9eba03126fa005e603ef6e6a48b93b4df6f1a509` succeeded (Fly release 204 complete). Public `/@schwegler/shelf?category=overall&theme=electric` exposed all three portrait layouts and rendered a genuine 1080×1920 canvas. Halloween activation, exact Undo and mobile overflow checks passed. Existing analytics CSP blocks appeared; no relevant seasonal/share runtime errors were observed. New refinement work remains a PR until separately merged/deployed.
