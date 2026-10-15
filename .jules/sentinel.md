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

## 2026-10-12 - Fix SQL Injection in Media Merge and User Filters
**Vulnerability:** Raw string interpolation in ActiveRecord queries (`where` and `joins` clauses) for dynamically generated table and column names in `app/controllers/users_controller.rb` and `app/services/admin/merge_media.rb`.
**Learning:** Even internal variables dynamically constructed (e.g. `#{table}.#{association}_type`) can flag SQL injection warnings or pose risks if caller arguments aren't strictly verified. Brakeman effectively catches these.
**Prevention:** Always use `ActiveRecord::Base.connection.quote_table_name` and `ActiveRecord::Base.connection.quote_column_name` for interpolating table and column names into raw SQL fragments. If raw SQL is used in `.joins`, ensure it is wrapped in `Arel.sql()` after quoting elements. Use bind variables (e.g., `?`) via `.where(..., value)` rather than `.where(Arel.sql(..., value))` which would drop the parameter in Rails.
## 2026-10-15 - [Reverse Tabnabbing in `link_to` helpers]
**Vulnerability:** Weakly configured external links missing `noopener noreferrer` in `link_to` elements with `target: '_blank'`.
**Learning:** Using `target: '_blank'` without `rel: 'noopener noreferrer'` allows newly opened tabs to have access to the `window.opener` object, creating a Reverse Tabnabbing vulnerability where the newly opened site could redirect the origin site to a phishing or malicious page.
**Prevention:** Make sure `rel: 'noopener noreferrer'` is specified in `link_to` elements or raw HTML `<a>` tags whenever `target: '_blank'` is present.
