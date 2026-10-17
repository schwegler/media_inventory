## 2024-05-18 - Prevent Stored XSS during String Interpolation into html_safe
**Vulnerability:** Unescaped model attributes (`issue_number`, `rating`) in `ActivitiesHelper#activity_link_description` were interpolated directly into strings marked `.html_safe`, creating a potential stored XSS vulnerability if maliciously formatted.
**Learning:** Rails' `link_to` automatically escapes tags but manual string interpolation combined with `.html_safe` does not. Even integer fields (like `issue_number`) or fields seemingly constrained by UI can receive malformed inputs (like scripts) depending on validation or underlying DB behavior.
**Prevention:** Always use `html_escape()` around user-controlled properties when manually constructing strings that will be returned as `.html_safe` to the view.
