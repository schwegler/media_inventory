## 2024-05-18 - Prevent Stored XSS during String Interpolation into html_safe
**Vulnerability:** Unescaped model attributes (`issue_number`, `rating`) in `ActivitiesHelper#activity_link_description` were interpolated directly into strings marked `.html_safe`, creating a potential stored XSS vulnerability if maliciously formatted.
**Learning:** Rails' `link_to` automatically escapes tags but manual string interpolation combined with `.html_safe` does not. Even integer fields (like `issue_number`) or fields seemingly constrained by UI can receive malformed inputs (like scripts) depending on validation or underlying DB behavior.
**Prevention:** Always use `html_escape()` around user-controlled properties when manually constructing strings that will be returned as `.html_safe` to the view.


## 2026-10-17 - Rating visibility during bounded summary optimization
**Decision:** Keep media-card rating privacy behavior unchanged while adopting the bounded-memory strategy recorded in `bolt.md`. Loading private rows server-side is not by itself a demonstrated disclosure: the existing loaded helper still filters other users' private ratings. The reason to reject the all-owner card preload in PR #603 (`2968abc`) / #605 (`e072c09`) is resource growth, not a newly established privacy leak.

**Guardrails:**
- A guest average includes only `is_public = true`. A signed-in average includes public entries OR entries owned by the current viewer; another user's false/NULL visibility entries stay excluded. Include the viewer's own false/NULL entry, count an own public entry once, and preserve the existing blank-rating denominator and one-decimal result.
- Fetch only the needed scalar own rating per title, not all owners/review bodies. Key any request summary cache by viewer identity plus polymorphic type and id; never share viewer-dependent summaries globally or reuse them for a different viewer.
- An explicit `user_library` may override the displayed personal rating only for its matching current owner. It must not replace the community average with an unsaved override or expose another person's private rating. Preserve and test existing nil/orphan wrapper behavior separately rather than silently changing it in a performance patch.
- Use bound values/Arel for visibility and owner predicates. Unrestricted legacy strings must retain existing Ruby conversion semantics; neither unsafe SQL interpolation nor rejecting previously accepted strings is a performance fix.

**Tests:** Cover guest versus owner versus another viewer, false/NULL visibility, public-own no-double-counting, unrated entries, viewer-cache isolation and explicit own/non-own overrides alongside the legacy parity and resource tests in `bolt.md`. `d9907cb4` had these regressions and passing [PostgreSQL CI](https://github.com/schwegler/media_inventory/actions/runs/38795319163); the later #603 commit removes them, so do not infer their protection from its stale PR description. Preserve unrelated Sentinel history and later security edits when reconciling the implementation.


## 2026-10-15 - [Reverse Tabnabbing in `link_to` helpers]
**Vulnerability:** Weakly configured external links missing `noopener noreferrer` in `link_to` elements with `target: '_blank'`.
**Learning:** Using `target: '_blank'` without `rel: 'noopener noreferrer'` allows newly opened tabs to have access to the `window.opener` object, creating a Reverse Tabnabbing vulnerability where the newly opened site could redirect the origin site to a phishing or malicious page.
**Prevention:** Make sure `rel: 'noopener noreferrer'` is specified in `link_to` elements or raw HTML `<a>` tags whenever `target: '_blank'` is present.
