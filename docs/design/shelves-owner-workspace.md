# Owner Shelves workspace follow-up

## Usability finding

The user’s actual screenshot (Library `libfile_2b1cf82b30a88191857ebd9ecb5a5679`, materialized and inspected locally) showed a structural failure: creation was buried under seven full exhibitions, far from its header action. It also showed cream text disappearing into an almost-white Custom shelves heading band, an isolated white mood selector among dark fields, muddy submit hierarchy and tiny owner controls. Passing prior functional checks did not establish a good creation flow. The lesson is to test the complete owner task and its first viewport in actual user themes, separately from exported artwork and public presentation.

Fresh state: #684 and #685 had already merged; deployment records confirmed production `bed36a1e` succeeded. This follow-up starts from that merged state and advances to master `242302fa`, preserving externally merged #688. No earlier branch is extended or overwritten.

## Design and routes

[Concept](shelves-owner-workspace-concept.png) was generated before the implementation inventory. The initial concept invented visibility settings; its correction removed that unsupported idea. The design uses the existing app’s Instrument Sans/Space Grotesk, semantic canvas/surface/inset/text/border/accent tokens and 44px targets. It separates management from the saved decorative shelf palettes.

- `/shelves`: authenticated owner’s workspace. Custom shelf rows first, prominent Create shelf, direct edit/settings/public links, then seven compact fixed favorite rows, followed by recoverable archives when present.
- `/shelves/new`: focused title/context/mood form, then a dedicated title editor. No nested form disclosures, no embedded exhibition before the form.
- `/shelves/:slug/edit`: owner-only item editor using the established cross-media picker, ordered selections, save guard and image exporter. Primary controls stay compact; secondary overview/profile/share actions use the existing native menu.
- `/shelves/:slug/settings`: focused title/context/media-mix/overview-count form with save/cancel. Archive is a separate reviewed operation.
- `/shelves/favorites/:category/edit` and `/shelves/appearance`: owner-only editing for preserved favorite and appearance semantics.
- Existing `/@handle/shelf` URLs remain stable and read-only, including for the owner. An owner-only contextual edit/workspace link replaces inline CRUD. Other signed-in users remain visitors.
- Existing account menu My Shelf entry reaches the workspace through `/shelf`; global navigation is otherwise unchanged.

## Preservation and permissions

| Capability | Owner workspace | Owner public view | Signed-in visitor / anonymous |
| --- | --- | --- | --- |
| Browse public selections | Public-view links | Yes | Yes under existing rules |
| Create / edit / reorder / publish preview | Yes | Contextual edit link | No |
| Archive / restore custom shelf | Confirmed action / restore | No inline action | No |
| Edit seven favorite shelves | Five picks each | Edit link | No |
| Read archived selections | Owner management only | Not found | Not found |
| Read library, private reviews or progress through shelf payload | No added access | No added access | No added access |

Existing IDs, slugs, URLs, picks, order, descriptions, presentation and attached preview images are retained. Display length never deletes selections. The 1,000-title operational limit and preserved capacity of legacy oversized shelves remain unchanged. Media restrictions affect new additions only. The existing catalog import does not imply ownership or create LibraryItems. Profile Collection/Backlog and In Progress remain distinct.

Named discovery still requires confirmed/handled ownership and a collection-specific **current** published preview. Generic or stale previews do not qualify. Archived collections are excluded before the existing metadata candidate window. Both 500-record lookbacks remain; older otherwise eligible shelves/previews can be omitted. Existing partial-recency UI disclosure and stable public payload are unchanged.

## Recoverability and migration

Archive replaces irreversible delete: the owner reviews the consequence and types the shelf title exactly. The server enforces ownership and a current edit version under the owner lock. Archive removes the shelf from public overview, direct shelf access and discovery, while retaining all selections and settings. Restore returns the original URL and can restore discovery eligibility when a current published preview exists. No shelf is hard-deleted. Existing exported or previously shared image URLs are not revoked by archiving; retained attachment bytes may still be available independently of the shelf route.

The additive migration introduces nullable `archived_at`; all existing shelves remain active. Rollback is reversible when no archives exist. If archives exist, rollback raises before removing protection rather than silently republishing archived shelves; restoration decisions require review first. Isolated checks verify two down/up cycles, exact prior data preservation, seven favorites, 1,000-title capacity and guarded rollback. No production migration has run.

Each independently opened Create form gets its own nonce (up to ten pending forms per session) and a deterministic shelf identity protected by the existing unique user/slug index. Repeated submissions cannot multiply shelves. New/settings forms retain invalid values, render errors, disable during Turbo submission and protect dirty navigation with a focus-managed leave dialog. Owner forms opt out of Turbo snapshots so stale nonces and discarded fields are not resurrected. Existing stale-save and item dirty-navigation protections remain.

## Visual comparison and evidence

Browser/IAB first verified the workspace, dark mobile create form, picker, save, public view and settings route. Its native confirm prompt stalled its browser control; documented recovery also failed. Remaining dialog and regression verification uses the repository’s Selenium/Chrome system tests. The focused form now uses an accessible code-native leave dialog for Turbo navigation; full page exits retain the standard browser guard. No unrelated OS dialog was changed.

Concept and final screenshots are inspected with `view_image`. Comparison points: custom-before-favorites hierarchy; prominent top creation action; intentional dark select/fields/placeholders; bright primary versus outlined cancel; label and control typography; mobile wrapping and 200% equivalent 640px reflow; focus-managed keep/discard dialog. Native tested sizes are 1280×900 desktop, 390×844 mobile and 640×450 reflow. At reflow height vertical scrolling is intentional and keyboard reaches the submit action.

Intentional implementation differences from the illustrative concept: retain Trove’s actual header/logo, existing semantic light/dark palettes and app spacing rather than the generated white dark-mode header; use approved fixture artwork and actual stored counts, with no invented favorites or placeholder covers; retain the established cover-based item editor rather than replace its tested ordering/picker/export behavior with a new list implementation; settings expose supported media mix and preview length, with no invented visibility control. No new mascot, social metric or review is introduced.

Technical checks and exact-head CI are recorded in the draft PR description. Screenshots are test-only synthetic-account evidence, not production content. Old screenshots captured before decoded artwork or during transient navigation are discarded from final deliverables.

Checkpoint evidence: [owner overview](../screenshots/shelves-owner-workspace/overview-dark-desktop.png), [create on mobile](../screenshots/shelves-owner-workspace/create-dark-mobile.png), [settings on mobile](../screenshots/shelves-owner-workspace/settings-dark-mobile.png), [leave confirmation](../screenshots/shelves-owner-workspace/leave-dialog-mobile.png). These four final captures were inspected; the overview waits for its two visible approved covers to decode.

### Post-merge browser navigation readiness

A combined SQLite regression run at seed 26539 raised Chrome's `-32000 Node with given id does not belong to the document` while Capybara evaluated visibility after settings-to-editor navigation. A separate unchanged shelf-only repetition reproduced the same error at original spec line 71: the visible Shelves heading assertion immediately after clicking Shelves workspace. External source-line tracing identified that callsite; four preceding repetitions passed. The differing destination pages rule out attributing the error solely to the dirty-form dialog. Evidence remains in `/tmp/shelf-traced-repeat-5.log` and `/tmp/shelf-traced-repeat-5/failures/` on the diagnostic executor.

The shelf spec now waits for a destination-specific marker under a non-busy, non-preview document outside an active View Transition before issuing the existing visible assertions or next interaction. The readiness query uses `visible: :all`, avoiding visibility evaluation on departing-document elements. All original native controls, visible content, keyboard focus, cancellation, saved-data, seven-favorite and reflow assertions remain. There are no driver-error rescues, click retries, sleeps, timeout increases, animation disabling, global-helper or product changes. The first fixed shelf run at seed 26539 passed 2/2 and targeted RuboCop passed. Combined-matrix validation remains necessary; the separate login-flash and import-save text failures are preserved rather than absorbed into this change.
