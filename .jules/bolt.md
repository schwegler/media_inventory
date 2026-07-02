## 2026-06-18 - Optimized Polymorphic Bulk Fetching
**Learning:** In this codebase, the `Activity` feed and "Popular Items" sections use polymorphic associations (`trackable`) that mix various media models. Standard polymorphic `includes` can be inefficient or fail if models have different associations (e.g., some have `cover_image`, others like `TvEpisode` don't).
**Action:** When bulk fetching polymorphic items, group by `trackable_type`, then perform a bulk query per type. Use `reflect_on_association` to conditionally include Active Storage attachments (like `cover_image_attachment: :blob`) to eliminate N+1 queries during view rendering while ensuring type safety.

## 2026-06-19 - Risks of Nested Eager Loading on Polymorphic Associations
**Learning:** Eager loading nested associations on a polymorphic relation (e.g., `includes(trackable: { tv_show: :user })`) will raise an `ActiveRecord::AssociationNotFoundError` if *any* of the returned records belong to a model that does not define that nested association (e.g., a `Movie` or `Album` which doesn't have a `tv_show`).
**Action:** Stick to first-level eager loading for polymorphic associations (`includes(:trackable)`) or use the grouping/bulk-fetch pattern if nested associations are required for specific types. Also, use `.load` in the controller if the view uses `.any?` or `.exists?` to prevent redundant COUNT queries before the SELECT.

## 2026-07-02 - Attachment N+1 Queries in Generic Controllers
**Learning:** Generic controllers (like `InventoryController`) that serve multiple models can easily introduce N+1 queries if they don't account for model-specific attachments like `cover_image`. Since `ActiveStorage` requires a separate query to check for attachment existence (`attached?`), viewing a list of 20 items can result in 20 additional queries.
**Action:** Use the `with_attached_cover_image` scope (safely wrapped in a `respond_to?` check) in the base controller's `index` action. This ensures that any model inheriting from the controller will bulk-load its attachments, keeping query counts constant.
