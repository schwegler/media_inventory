## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-22 - [Information Leakage on Landing Page and Profile Feed]
**Vulnerability:** Private activities and reviews associated with `LibraryItems` were visible on the landing page and dashboard to any user or guest. Also, user posts were visible to visitors on profile feeds despite being intended as private.
**Learning:** Privacy filtering must be applied at every entry point, including aggregated feeds like landing pages and social dashboards. Using `INNER JOIN` for filtering polymorphic activities can accidentally hide non-media activities (like follows or posts); `LEFT OUTER JOIN` with careful `NULL` handling is safer for maintaining functionality while enforcing privacy.
**Prevention:** Centralize privacy scopes or ensure all activity fetching logic joins with the ownership/privacy model (e.g., `LibraryItem`) and checks the `is_public` flag and `current_user` ownership.
