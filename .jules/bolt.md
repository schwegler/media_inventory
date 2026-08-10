## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-08-10 - Optimizing Recursive Tree Associations in Rails Views
**Learning:** Calling database-backed association methods (like `.where(parent_id: nil)` or `.count`) on preloaded associations (e.g., `comments` or `replies`) completely bypasses the preloaded cache, triggering N+1 database queries and redundant `SELECT COUNT(*)` queries during view rendering.
**Action:** Always check `.loaded?` before accessing associations in views. Use in-memory operations like `.select { |x| x.parent_id.nil? }` instead of `.where` and `.size` instead of `.count` or `.any?` to leverage preloaded in-memory collections, and load un-preloaded relations into arrays using `.to_a` to combine checks and rendering into a single database hit.
