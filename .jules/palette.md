## 2025-05-15 - Accessible Star Ratings
**Learning:** Star ratings rendered as pure text (e.g., "★★★") are often skipped or misread by screen readers if they lack proper ARIA roles and labels. Using a semantic `<span>` with `role="img"` and a descriptive `aria-label` ensures all users can understand the rating.
**Action:** Always use the `render_stars` helper instead of manual interpolation, and ensure the helper outputs accessible HTML with `role="img"` and `aria-label`. When interpolating this helper in Ruby helpers, use `html_safe` or `safe_join` to prevent escaping the HTML tags.
