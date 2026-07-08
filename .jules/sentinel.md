## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-21 - [Information Disclosure in Diagnostic Endpoints]
**Vulnerability:** The `/db_status` endpoint in `LandingController` was publicly accessible and leaked database connection status and partially filtered `DATABASE_URL` environmental data.
**Learning:** Diagnostic endpoints added during development often bypass standard authentication filters if not explicitly included in a security scope. Even filtered environment variables can provide enough context for an attacker to map infrastructure.
**Prevention:** Always place diagnostic or internal metric endpoints behind administrative authentication filters (`authenticate_admin`) and ensure they are declared as public methods in the controller to be reachable by the router.

## 2026-06-21 - [Shared Catalog Integrity Risks]
**Vulnerability:** Regular users could theoretically modify the global metadata (title, release year) of shared media items in the `InventoryController#update` action, potentially corrupting the catalog for all users.
**Learning:** Base controllers that handle both personal data (`LibraryItem`) and shared data (`Movie`, `Book`) must explicitly distinguish between the two for authorization purposes. `assign_attributes` should be guarded by role-based checks when dealing with shared records.
**Prevention:** Restrict "global" metadata modifications to administrators (`current_user.admin?`) while allowing regular users to manage their personal associations via separate logic.
