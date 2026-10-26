# Review excerpts and feed permalinks

PR #683 introduced the dedicated `/reviews/:id` page. It was merged externally at `8aa0b9e1` before the excerpt refinement was committed. That merged community template still used `simple_format(matching_item.review)`. An anonymous request to `/albums/29-confessions-ii-2026` on 2026-10-26 confirmed 9,976 characters in 12 community-review paragraphs with no excerpt wrapper. This is missing deployed behavior, not evidence of a cache problem.

`ReviewExcerpt` now produces a sanitized, balanced HTML fragment with a default maximum of 480 Unicode graphemes, three nonempty paragraphs/list items and five explicit line breaks. Compact feeds use 220 graphemes/two paragraphs/three breaks. The renderer stops at a word boundary where possible and never splits a grapheme. Omitted nodes, including their active links, do not appear in the fragment. Inline images are omitted with a full-review link. This is server-side presentation only: stored review text, the review editor and the dedicated review page remain complete.

The shared partial preserves safe emphasis, lists, links and paragraph/line boundaries. A shortened summary says **Read full review**. Short reviews stay complete without an excerpt-expansion link in entity/owner summaries. Review events in feeds also show **View review** when short, so their only destination is never the catalog title. Link labels identify the author and title, and escape enclosing Turbo frames.

## Rendering paths

| Surface | Behavior |
| --- | --- |
| Media community and owner review blocks | Shared normal excerpt |
| Owner tracking summary | Shared compact excerpt |
| Episode/issue progress and series entries | Shared normal excerpt; existing edit/progress controls retained |
| Turbo review updates | Same shared summary as the original media response |
| Dashboard circle and popular reviews | Compact excerpt plus review-event permalink, including short reviews |
| Logged-out general activity | Compact excerpt plus review-event permalink |
| Profile overview and Activity tab | Shared activity partial; legacy catalog-backed events batch-resolve their owner's visible library review |
| Profile Likes | Written library reviews link to their review page; inaccessible reviews remain filtered |
| Public JSON reviews API | Additive canonical `review_url`; existing full plain-text `body` and `item_url` contracts retained |
| ActivityPub outbox | Explicitly public written reviews only, bounded safe note content and canonical review URL |
| Dedicated review page | Full sanitized text; unchanged owner/public authorization and spoiler-safe preview metadata |

Catalog/shelf cards without review bodies do not gain new review text. The orphaned wrestling-event view has no model/controller/route in the current app and is not an active rendering path. Game journal/milestone spoiler content is not included in review excerpts or feeds. Authentication, inbox, CSRF and account security configuration are unchanged.

Regression evidence includes a synthetic Madonna/CONFESSIONS II review with twelve long paragraphs; complete short reviews; nested emphasis/links; balanced raw response fragments; combining characters and emoji sequences; long unbroken strings; removed tail URLs; private/public-preview exclusion; actual HTML feed links; JSON/ActivityPub permalinks; and keyboard navigation from a mobile/desktop community excerpt to the complete review. Feed authors/media are reused, with a zero-SELECT helper query regression when supplied records are already loaded.
