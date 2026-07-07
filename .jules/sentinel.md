## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-22 - [Exposure of Diagnostic Endpoints]
**Vulnerability:** The `/db_status` endpoint was publicly accessible, leaking sensitive database connection strings (partially filtered) and internal application metrics (user and activity counts).
**Learning:** Diagnostic or "status" endpoints added for troubleshooting are frequently overlooked during security reviews. If they rely on environment variables like `DATABASE_URL`, they can accidentally expose infrastructure details even if some filtering is applied.
**Prevention:** Always wrap diagnostic endpoints in administrative authentication filters (`before_action :authenticate_admin`). Avoid exposing environment variables directly in JSON responses, even with regex filtering.
