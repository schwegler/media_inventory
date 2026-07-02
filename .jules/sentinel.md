## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-06-22 - [Timing Attack Protection in Authentication]
**Vulnerability:** Standard `User.find_by(email: ...)` followed by `user&.authenticate(...)` is vulnerable to timing attacks. An attacker can determine if an email exists in the system by measuring how long the server takes to respond (bcrypt hashing only happens if the user exists).
**Learning:** Rails 7.1+ provides `authenticate_by` which performs constant-time verification even if the record is not found.
**Prevention:** Use `User.authenticate_by(email: email, password: password)` instead of manual lookup and authentication in controllers.
