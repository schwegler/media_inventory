# Media-detail visual QA

Screenshots use isolated synthetic test fixtures, not production accounts or invented catalog information shipped to users. Screens show desktop dark mode, mobile light mode, 320px reflow, and the fully expanded no-JavaScript fallback. Public shelf rows use published test selections and catalog artwork only.

The browser suite checks keyboard arrows/Home/End selection, history back/forward, direct category fragments, searchable beforematch reveal, Show all, unchanged top-level document anchors, visible synopsis, quick tracking, all six catalog types, track/issue/episode preservation and overflow. Native browser find-menu UI and assistive-technology speech output were not manually audited; searchable panel behavior and ARIA structure are covered in browser tests.

The named-shelf mobile screenshot shows a collection with an explicitly published current preview. The browser test follows its actual anonymous public URL, edits the collection afterwards, and verifies that the stale preview no longer makes it discoverable. The discovery subtitle states the recent-window incompleteness.
