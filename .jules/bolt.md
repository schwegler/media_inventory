## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-08-04 - In-Memory Likes Cache Invalidation & Object Identity
**Learning:** Checking polymorphic `likes.exists?` inside loop structures (like user feeds or lists) is a major N+1 SQL pattern. Caching these checks in-memory as a `Set` on the `User` instance eliminates O(N) queries, but invalidation depends on in-memory object references. If a `Like` is created or destroyed, callbacks trigger `clear_likes_cache` on the associated `user` instance, which must be synchronized in memory (e.g. `like.user = user` in test environments).
**Action:** When caching model attributes in-memory, always pair the cache with robust `after_commit` hooks on mutating operations to invalidate the cache, and ensure the same in-memory object reference is updated during mutations.
