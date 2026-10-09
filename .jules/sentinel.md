## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.
## 2023-10-09 - Safe Dynamic Table Querying in Rails
**Vulnerability:** A `SQL Injection` warning was reported by Brakeman because a user-provided search term and an internally mapped table name were used via string interpolation `where("#{table_name}.title LIKE ?", "%#{@query}%")`. Although `table_name` was sanitized through `sanitize_join_sql`, Brakeman correctly flagged string interpolation in the `where` clause as risky.
**Learning:** Raw string interpolation in SQL string arguments is fundamentally unsafe and trips automated static analysis scanners. Rails provides the Arel library which allows constructing queries dynamically using object methods.
**Prevention:** Always use Arel table abstractions such as `Arel::Table.new(table_name)[:title].matches(...)` instead of raw string interpolation when the queried table must be determined dynamically at runtime.
