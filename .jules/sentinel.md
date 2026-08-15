## 2026-06-19 - [Authorization Bypass on Polymorphic Resources]
**Vulnerability:** Access control was missing on several endpoints that interact with media items via polymorphic associations (`CommentsController#create`, `LikesController#toggle`, `MediaController#copy`). Users could comment on, like, or copy private media items belonging to other users.
**Learning:** Centralizing authorization logic in `ApplicationController` (e.g., `can_access?`) is essential but requires careful handling of varied model structures. For instance, `TvEpisode` does not have a direct `user_id` but inherits ownership from its parent `TvShow`.
**Prevention:** Always verify ownership or public status before allowing interactions with resources, especially when using `constantize` on user-provided type parameters. Always use whitelists when dynamically instantiating classes from user input.

## 2026-06-20 - [Authentication Bypass via Nil Password Comparison]
**Vulnerability:** In `SessionsController`, the Bluesky login used `user.bsky_password == bsky_password`. In Ruby, `nil == nil` is true. If a user hadn't set an app password and the attacker provided a null/missing parameter, they could log in.
**Learning:** Never rely on direct equality for password comparison without ensuring both sides are present. Even with `has_secure_password`, custom authentication flows must explicitly validate input presence.
**Prevention:** Always check `.present?` on password parameters before attempting any comparison or authentication logic.

## 2026-08-15 - [Authentication Bypass via Subclass Callback Overrides]
**Vulnerability:** `InventoryController` intended to secure resource mutation actions via `before_action :logged_in_user`, but specified `only: %i[new create]`. Subclasses (`MoviesController`, `BooksController`, `VideoGamesController`) also re-declared `before_action :logged_in_user, only: %i[new create]`, overriding parent controller filters and allowing unauthenticated users to invoke `edit`, `update`, and `destroy`.
**Learning:** In Rails ActionController, re-declaring an inherited `before_action` filter in child controllers with an `only:` clause can shadow or restrict the filter scope defined in the parent class.
**Prevention:** Centralize authentication filters on base controllers covering all mutating actions (`only: %i[new create edit update destroy]`) and avoid re-declaring the same `before_action` in child controllers.
