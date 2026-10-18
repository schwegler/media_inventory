# Imported metadata audit

Base: master 876351c2 (2026-10-18). No production catalog calls or writes.

| Type | Search → detail → stored/displayed | Gap and treatment |
| --- | --- | --- |
| Movie | TMDB/iTunes summaries → MetadataProvider → scalar credits, structured people and metadata_details → entity links/provider facts | Detail lookup happened after confirmation; callback repeated requests and could replace edits. Fetch selected detail before confirmation, persist signed fields, retain background refresh. |
| TV | TVMaze/TMDB/iTunes → network/credits/genres/year + episodes → people/categories, provider facts and series | Keep episode jobs and bounded season coverage; explain children load after save, expose partial/error status. |
| Album | iTunes/MusicBrainz → artist/genres/year/credits/details + tracks → entities/provider facts/track list | Structured fields previously had no form transport. Signed payload carries them; tracks remain background work. |
| Book | OpenLibrary/iTunes → authors/publisher/edition facts → entities/provider facts | OpenLibrary detail year/cover absent. Add detail mapping; retain summary fallback when optional edition lookup fails. |
| Comic | ComicVine/OpenLibrary → writer/artist/publisher + issues → people/issues | OpenLibrary author had no Comic attribute; map to writer. Volume is a series, not an issue: do not invent issue numbers. |
| Game | Steam/RAWG → game type/developer/publisher/platform/metadata_details → catalog identity, people/categories, provider details | Preserve GameCatalogIdentity, signed local identity, personal copies/playthroughs and existing refresh permissions. |

Across types, rendered preview image URLs and stored cover-source URLs are distinct. Keep `cover_source_url` when present; uploads remain editable. Search auto-selection must not assign identity. Manual entry must clear provider identity for all types. Existing shared catalog selections must not overwrite catalog values from logging forms.

Imported metadata is a read-only confirmation with source, missing values and lookup status. Personal collection/backlog, ownership, rating, review, visibility and dates remain editable. Manual metadata remains editable. Use “Use as manual entry” before saving to correct a new independent entry; for existing shared catalog corrections use the reviewed Suggest an edit flow. Refresh retains non-provider edits. No claim that every source provides every field. Wikipedia/Archive search summaries remain usable when detailed refresh is unsupported.

Additional provider losses fixed: TVMaze summary/runtime, ComicVine series description/start year/issue count, iTunes video description/runtime/content rating, OpenLibrary work descriptions and non-ISO historic publication dates. These map to existing `metadata_details` and its rendered facts rather than adding new catalog columns.

Reviewed corrections also cover displayed provider facts (descriptions, runtime, editions, ISBNs, language/genre lists). The form uses labels and ordinary text/number fields rather than JSON. Approval validates supported keys, preserves number/list types, and records per-key refresh protection so unrelated facts continue updating. Internal provider identifiers and nested arbitrary objects are excluded.

Reported production examples were supplied read-only, not fetched or modified by this task: comics 293/294/295 have issues but missing volume writer/artist values; Book 202's DARKSIDE publisher may identify an edition; Album 23's “JuJu (Remastered)” title identifies the selected release. Volume APIs may omit role-specific credits even when issue APIs expose them. Edition/release provenance should remain visible rather than flattening these into invented canonical values.

OpenLibrary work previews explicitly label facts borrowed from one available edition. A known work publication year from search is retained when the work detail response omits it, instead of replacing it with that edition's year. Edition publication date remains separately visible. Provider release titles such as “Remastered” are retained.

Selected details use an authenticated, CSRF-protected POST body, avoiding URL limits for long game descriptions. Cached signed selections remain stable during unchanged polling (including local game identity tokens), with bounded expiry. Reviewed cleared credits, classifications and genres remain protected through both explicit refresh and queued game enrichment; uploaded covers and unrelated contributor roles remain intact.
