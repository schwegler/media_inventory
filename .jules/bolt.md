## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-06-26 - Eager Loading User Avatars in Lists and Feeds
**Learning:** Rendering user avatars in long lists (Users index) or activity feeds triggers N+1 queries because Active Storage attachments are not eagerly loaded by default with the `:user` association. Standard `includes(:user)` only fetches the user record, but each `user.avatar.attached?` check in the view then triggers an additional query.
**Action:** Use `.with_attached_avatar` on User relations for simple lists. For polymorphic feeds preloaded via `RecordPreloader`, use nested preloading: `{ user: { avatar_attachment: :blob } }` instead of just `:user` to ensure avatars are bulk-fetched alongside user records.
