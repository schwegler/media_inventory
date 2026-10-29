# Compact metadata on new visits

The October 26 screenshot shows the intended presentation: the Details tab selected, one metadata panel visible, and an explicit Show all option. The visual design is unchanged.

## Reproduced cause

On live `/tv_shows/157-the-good-wife-2009`, an isolated anonymous Chrome session showed:

1. Cold document load: compact tabs, Details selected, Show all button.
2. Explicit Show all: expanded metadata, Show tabs button.
3. Back to the TV catalog, then a new Turbo visit to the same title: expanded metadata again despite a new Turbo restoration identifier.
4. Reload: compact tabs again.

The controller's module-level presentation map was keyed by pathname, so an explicit choice from an earlier visit became the default for every subsequent Turbo visit to that title. Its fallback also trusted expanded attributes in cached DOM. Neither server metadata nor content privacy caused the behavior.

## Behavior

New visits start compact, including a new visit to a previously expanded title. Fresh document loads and reloads start compact too. A direct metadata fragment selects its containing panel; downstream document fragments keep the existing post-enhancement alignment.

Show all remains an explicit button. Back/Forward restores that choice for its Turbo visit, without applying it to a later visit to the same URL. Presentation memory is keyed to Turbo restoration identifiers and remains bounded to the 20 most recent entries. Existing history state is preserved. No catalog content or tracking state is stored in this map.

Server HTML continues to contain every metadata category. Without JavaScript, or when the browser lacks searchable until-found panels, the accessible full-document fallback remains intact. In supported browsers inactive panels remain searchable and keyboard navigation, fragment selection and reveal-on-find are unchanged.

## Verification

The focused browser suite covers two visits to the same title with independent compact/expanded choices, Back/Forward across both entries, reload after Show all, direct fragments, searchable inactive panels, keyboard control, desktop/mobile/light/dark/reflow and no-JavaScript access. Cold loads and reload defaults are checked for books, albums, comics, TV and games as well as movies. Existing strict document-anchor and header-spacing assertions remain unchanged.

The live production page was only read and its local presentation toggled in an isolated headless session. The fix has not been deployed. Screenshots use isolated synthetic test fixtures.
