# Compact metadata default evidence

These screenshots contain isolated synthetic browser-test fixtures, never production user content.

- `fresh-visit.png`: a new Turbo visit to a title previously expanded through Show all; Details opens compactly again.
- `mobile-dark.png`: the existing accessible tab layout at 390px, with the Cast tab selected by the keyboard/click test.
- `reflow-light.png`: compact tabs at 320px, equivalent to 200% reflow from 640px, with long credits.

The focused metadata/section/header suite passed 19 examples. It covers independent Back/Forward restoration for two visits to the same title, cold loads and reloads for all six media types, fragments, keyboard controls, browser text-search discovery/reveal, light/dark responsive layout, and no-JavaScript full content. Native browser Find UI and assistive-technology speech were not manually audited in this follow-up; their underlying markup/reveal behavior is unchanged.
