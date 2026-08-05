## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-06-20 - Eager-Loaded Collections vs SQL Re-Evaluation in Views
**Learning:** Even when associations are fully eager loaded/preloaded in the controller (e.g., `includes(comments: [:user, :likes, replies: [:user, :likes]])`), common Rails view helpers like `.where(...)`, `.count`, and `.any?` (with criteria/no arguments under some setups) will bypass the in-memory cache and issue fresh database queries. This leads to hidden O(N) database N+1 N+1 queries during view rendering.
**Action:** Always check `.loaded?` on the association in views. If loaded, use in-memory Ruby operations like `.select { |x| x.field.nil? }` instead of `.where(...)`, and use `.size` instead of `.count` to guarantee that the preloaded cached array is utilized instead of forcing SQL re-evaluation.
