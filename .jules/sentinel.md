## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-22 - [Global Metadata Authorization Bypass]
**Vulnerability:** In `InventoryController`, regular users could modify global metadata of shared media items (like Movie titles or TV show details) by including those parameters in their personal library update requests.
**Learning:** Shared base controllers using polymorphic associations or generic resource management must distinguish between "global" metadata (shared by all users) and "personal" metadata (scoped to a specific user's relationship with that item).
**Prevention:** Strictly enforce `admin` checks for any modifications to shared/global resource attributes, while allowing users to manage their own associations with those resources. Use `new_record?` checks in "find-or-create" flows to allow initial population of metadata by non-admins during resource creation.
