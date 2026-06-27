## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-27 - [XSS in Activity Feed via Malicious Rating]
**Vulnerability:** User-provided ratings were interpolated directly into HTML-safe strings in `ActivitiesHelper#activity_link_description`. If a user provided a rating containing a script tag, it would execute in the browser of anyone viewing the activity feed.
**Learning:** Even if a field is expected to be numeric, if the database type is a string and there is no strict validation, it must be treated as unsafe user input. `html_safe` combined with string interpolation is a common source of XSS.
**Prevention:** Always use `html_escape` (or the `h` alias) when interpolating variables into strings that will be marked as `html_safe`. Better yet, use Rails tag helpers which handle escaping automatically.
