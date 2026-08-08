## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-08-08 - [Information Disclosure on Diagnostics Endpoint]
**Vulnerability:** The `/db_status` diagnostic action was placed in `LandingController` below the `private` visibility keyword. Although this made it inaccessible via Rails routes (resulting in 500/NoMethodError page rendering with potential trace leaks), if made public, it exposed raw database status, counts, and filtered database credentials to unauthenticated users.
**Learning:** Diagnostic endpoints should always be explicitly mapped as public actions and proactively secured using central filters (`before_action :authenticate_admin`). Placing them under private helper blocks can also mask incorrect routing behavior.
**Prevention:** Define reusable admin protection helper methods (`authenticate_admin`) in `ApplicationController` and systematically apply them to all diagnostic, monitoring, or metadata administration routes.
