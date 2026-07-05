## 2025-06-22 - Accessible Star Ratings Pattern
**Learning:** Manual star string construction (e.g., "4.5 ★") is inaccessible to screen readers and inconsistent across views. Using a standardized helper that wraps ratings in semantic HTML (`role="img"`, `aria-label`) provides a better UX for all users.
**Action:** Use the `render_stars` helper in `ApplicationHelper` for all rating displays. Ensure `ActivitiesHelper` includes `ApplicationHelper` to maintain consistency in feed descriptions.
