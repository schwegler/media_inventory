## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-07-28 - [Server-Side Request Forgery via OmniAuth Setup]
**Vulnerability:** Users could specify arbitrary local or internal hostnames/IPs (e.g., `localhost`, `127.0.0.1`, `169.254.169.254`) as a Mastodon server name during OmniAuth setup. The application would then perform backend HTTP POST requests (`Net::HTTP`) to register an application on the target, creating a classic SSRF risk.
**Learning:** Dynamic server/host registration endpoints must always validate that the target hosts resolve exclusively to public, non-reserved IP addresses before sending HTTP requests.
**Prevention:** Use a robust host validation helper utilizing `Resolv` and `IPAddr` to verify that all resolved IP addresses are public, non-private, non-loopback, and non-link-local.
