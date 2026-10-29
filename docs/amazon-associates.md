# Amazon searches and original reading guidance

Integration for Associates ID `schweg-20`; the account awaits final review. No deployment, production import, data migration, or account change is part of this PR. The retired ID is never accepted as configuration.

## Coverage and eligibility

Inspection of the current master found one Amazon search builder in `MediaSourcesHelper`, shared by catalog title pages. Its previous “Buy on Amazon” wording implied more than a search result. Related taco ’bout it cards contain imported excerpts; personal library reviews can be private and cannot establish editorial eligibility. Provider descriptions, ratings, article associations and the mere presence of a review do not enable paid links.

The conservative initial gate is a code-reviewed handwritten reading guide in `HalloweenReading`: only Book records with the exact title AND author Dracula/Bram Stoker or Frankenstein/Mary Shelley qualify. The original guide is rendered in the title page’s main content column, with edition-selection guidance and a borrowing alternative. The sources card stays concise. These are original Halloween reading prompts, not personal testimonials or imported reviews. Adaptations, other authors, title variants, missing authors, every other book and other media types remain ordinary untagged searches. This intentionally favors false negatives. Expand only with relevant original guidance and tests; do not replace it with a metadata-presence check. No production catalog was queried or modified to manufacture coverage.

`media_source_links` defaults to ordinary searches even for these books. Only the main title-page template opts in after resolving and rendering the guide on that page; other sources-partial callers default to ordinary searches. Cached WordPress excerpts and user content have no role in the gate. The gate does not query users, reviews, sessions or editorial caches.

## Configuration and links

`AMAZON_ASSOCIATES_TAG` defaults to `schweg-20`, the assigned ID. An explicitly blank value disables paid links. Nil, malformed or different configured IDs fail closed. This is an intentional single-account allowlist, not an arbitrary tracking-ID input.

URLs are constructed from scratch using `URI.encode_www_form`; there is one literal title query and at most one fixed tag. No user-specific identifiers, sub-tags, click tracking, cookies, redirects or Amazon requests are added. Existing provider links retain their behavior. Paid links say “Search Amazon (paid link)”, use `sponsored noopener noreferrer`, and retain the proximate “(paid link)” label. The global footer displays “Some links are paid links. As an Amazon Associate I earn from qualifying purchases.” at a readable 14px. This Amazon statement is not a claim that one footer satisfies every affiliate program. Guidance and footer disclosure are outside collapsible content and remain readable at mobile widths. The per-link paid label remains visible without scrolling to the footer.

No prices, availability, Amazon reviews, Amazon images, endorsements or purchase guarantees are introduced. Existing catalog artwork remains unrelated to the Amazon link.

## Rules and verification

Amazon's [Participation Requirements](https://affiliate-program.amazon.com/help/operating/policies) allow search-result links with additional relevant original content and prohibit user-specific sub-tags. Its [disclosure guidance](https://affiliate-program.amazon.com/help/node/topic/GHQNZAU6669EZS98) specifies conspicuous link-level disclosure and the Associate statement. Reviewed 2026-10-24. Registration and pending account status are supplied by the owner; this PR does not claim final acceptance.

Helper tests cover default callers, exact decoded Unicode/punctuation queries, tag injection/duplication, missing/blank/retired configuration and existing sources. Service tests cover title/author/type eligibility. Browser tests use synthetic test-only books at 1440×1000 and 390×844, check labels, disclosure visibility/size, link attributes, overflow, page identity, console and library navigation, and capture screenshots through `UI_QA_DIR`. The browser spec is included in exact-head Rails CI alongside the existing title/library and remembered-sign-in suites.

PR #666 remains separate. No homepage, authentication, session, library or title hierarchy implementation is changed. The CI edit adds one test line to the existing browser list.
