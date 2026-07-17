## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-07-17 - Polymorphic Likes preloading using ActiveRecord
**Learning:** Polymorphic like counts and liked status queries on list views (user feeds, activities, collection items) trigger severe O(N) database N+1 queries. Using ActiveRecord `.group` and `.pluck` with base classes allows batching like counts and statuses into exactly two database queries regardless of the list size.
**Action:** Call `preload_likes_data` on a unified, flat array of all fetched list items in the controller before rendering. In the view, query the preloaded caches via application helper fallbacks instead of calling `.likes.count` or `.liked?` directly. Use `.size` instead of `.count` on preloaded associations.
