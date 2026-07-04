## 2026-07-04 - [Accessible Star Ratings]
**Learning:** When using icon-based ratings (like stars), it's critical to provide a semantic wrapper with ARIA labels for screen readers. Using '½' instead of '.5' is more visually pleasing but needs a clear 'aria-label' to be interpreted correctly by assistive technology.
**Action:** Use the centralized `render_stars` helper which wraps symbols in a semantic `<span>` with `role="img"`, `aria-label`, and `title`.
