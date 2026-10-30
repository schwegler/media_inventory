# Retire Halloween 2026

Halloween's campaign is disabled and `activeSeason` is cleared in the shared configuration. Application and public shelf layouts use `available_season`, so neither mounts the controller, invitation, atmosphere or seasonal controls. The account seasonal picker is absent while no campaign is available. Saved account, browser and per-tab Halloween choices cannot activate the disabled campaign; their values are retained. Base appearance, profile decoration, manually selected shelf/export palettes, library state and tracking are unchanged.

The date window alone only stopped invitations: an explicitly saved Halloween appearance could persist. The enabled flag is the retirement switch for both Ruby rendering and JavaScript restoration. Christmas remains disabled with no artwork. Controllers, CSS, assets, schema and saved choices remain available for future approved seasonal work.

## Release checklist

- Review and merge this draft only after approval; no production deployment or release tag is part of this preparation.
- Confirm CI passes on the exact reviewed head.
- After the normal production deployment, verify guest home, signed-in navigation, appearance settings and public shelves have no seasonal invitation/atmosphere.
- Verify a returning account with Halloween saved retains its base appearance and library/tracking settings, and fresh/returning guest browser sessions show no overlay.
- To prepare Christmas: supply approved artwork and styling, update the dated campaign, enable it explicitly, and test both invitation and saved-choice flows before release. Do not simply enable the existing asset-less placeholder.
