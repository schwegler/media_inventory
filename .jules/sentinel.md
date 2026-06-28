## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-28 - [XSS in Activity Feed Ratings]
**Vulnerability:** User-provided ratings were interpolated into `html_safe` strings in `ActivitiesHelper#reviewed_description` without escaping. This allowed arbitrary HTML/JS injection via the rating field.
**Learning:** Even simple fields like ratings can be vectors for XSS if they are user-controlled and rendered in an `html_safe` context. Relying on Rails' automatic escaping is only safe when the entire string is NOT marked as `html_safe`.
**Prevention:** Always use `html_escape` (or its shorthand `h`) when manually constructing HTML strings with user data before calling `.html_safe`.
