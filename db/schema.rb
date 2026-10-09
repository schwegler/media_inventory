# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_09_181000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.string "activity_type", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.integer "trackable_id", null: false
    t.string "trackable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "albums", force: :cascade do |t|
    t.string "api_id"
    t.string "artist"
    t.datetime "created_at", null: false
    t.string "external_url"
    t.string "genre"
    t.integer "release_year"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_albums_on_api_id"
    t.index ["created_at"], name: "index_albums_on_created_at"
  end

  create_table "api_configurations", force: :cascade do |t|
    t.string "access_token"
    t.string "base_url"
    t.datetime "created_at", null: false
    t.boolean "is_active"
    t.string "media_type"
    t.text "options"
    t.string "source_name"
    t.datetime "updated_at", null: false
  end

  create_table "books", force: :cascade do |t|
    t.string "api_id"
    t.string "author"
    t.datetime "created_at", null: false
    t.string "external_url"
    t.string "publisher"
    t.integer "release_year"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_books_on_api_id"
    t.index ["created_at"], name: "index_books_on_created_at"
  end

  create_table "comic_issues", force: :cascade do |t|
    t.integer "comic_id", null: false
    t.datetime "created_at", null: false
    t.integer "issue_number"
    t.string "provider_id"
    t.string "publisher"
    t.string "rating"
    t.boolean "read", default: false, null: false
    t.date "read_at"
    t.string "release_date"
    t.text "review"
    t.text "summary"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["comic_id", "provider_id"], name: "index_comic_issues_on_comic_id_and_provider_id", unique: true
    t.index ["comic_id"], name: "index_comic_issues_on_comic_id"
    t.index ["created_at"], name: "index_comic_issues_on_created_at"
  end

  create_table "comics", force: :cascade do |t|
    t.string "api_id"
    t.string "artist"
    t.datetime "created_at", null: false
    t.string "external_url"
    t.integer "issue_number"
    t.string "publisher"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "writer"
    t.index ["api_id"], name: "index_comics_on_api_id"
    t.index ["created_at"], name: "index_comics_on_created_at"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "commentable_id", null: false
    t.string "commentable_type", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "parent_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["created_at"], name: "index_comments_on_created_at"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "cover_imports", force: :cascade do |t|
    t.datetime "attempted_at"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.datetime "ready_at"
    t.string "source_url", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_cover_imports_on_item"
    t.index ["item_type", "item_id"], name: "unique_cover_import_item", unique: true
    t.index ["state", "attempted_at"], name: "index_cover_imports_on_state_and_attempted_at"
  end

  create_table "edit_suggestions", force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.json "proposed_changes"
    t.string "status"
    t.integer "suggestable_id", null: false
    t.string "suggestable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["status", "created_at"], name: "index_edit_suggestions_on_status_and_created_at"
    t.index ["suggestable_type", "suggestable_id"], name: "index_edit_suggestions_on_suggestable"
    t.index ["user_id"], name: "index_edit_suggestions_on_user_id"
  end

  create_table "game_copies", force: :cascade do |t|
    t.string "access_method", default: "digital", null: false
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "edition"
    t.integer "imported_playtime_minutes"
    t.integer "library_item_id", null: false
    t.text "notes"
    t.string "ownership_status", default: "owned", null: false
    t.string "platform", null: false
    t.date "purchase_date"
    t.decimal "purchase_price", precision: 12, scale: 2
    t.string "steam_app_id"
    t.string "storefront"
    t.datetime "updated_at", null: false
    t.index ["library_item_id", "steam_app_id"], name: "index_game_copies_on_library_item_id_and_steam_app_id", unique: true
    t.index ["library_item_id"], name: "index_game_copies_on_library_item_id"
  end

  create_table "game_external_ids", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.integer "video_game_id", null: false
    t.index ["provider", "external_id"], name: "index_game_external_ids_on_provider_and_external_id", unique: true
    t.index ["video_game_id"], name: "index_game_external_ids_on_video_game_id"
  end

  create_table "game_journal_entries", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "library_item_id", null: false
    t.boolean "spoiler", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["library_item_id"], name: "index_game_journal_entries_on_library_item_id"
  end

  create_table "game_library_views", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "filters", default: {}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_game_library_views_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_game_library_views_on_user_id"
  end

  create_table "game_playthroughs", force: :cascade do |t|
    t.date "completed_on"
    t.datetime "created_at", null: false
    t.string "difficulty"
    t.integer "library_item_id", null: false
    t.text "notes"
    t.string "platform"
    t.integer "progress", default: 0, null: false
    t.string "route"
    t.date "started_on"
    t.string "status", default: "backlog", null: false
    t.datetime "updated_at", null: false
    t.index ["library_item_id"], name: "index_game_playthroughs_on_library_item_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at", null: false
    t.integer "game_playthrough_id", null: false
    t.text "milestones"
    t.text "notes"
    t.datetime "started_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_playthrough_id"], name: "index_game_sessions_on_game_playthrough_id"
  end

  create_table "library_items", force: :cascade do |t|
    t.boolean "consumed"
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.boolean "in_backlog"
    t.boolean "is_collected"
    t.boolean "is_public"
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.boolean "owned_digitally", default: false, null: false
    t.string "owned_digitally_format"
    t.boolean "owned_physically", default: false, null: false
    t.string "owned_physically_format"
    t.string "rating"
    t.text "review"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_library_items_on_created_at"
    t.index ["item_type", "item_id"], name: "index_library_items_on_item"
    t.index ["user_id", "in_backlog", "created_at"], name: "index_library_items_on_user_id_and_in_backlog_and_created_at"
    t.index ["user_id", "is_collected", "created_at"], name: "index_library_items_on_user_id_and_is_collected_and_created_at"
    t.index ["user_id", "is_public", "item_type", "created_at"], name: "index_library_items_on_public_catalog"
    t.index ["user_id"], name: "index_library_items_on_user_id"
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "likeable_id", null: false
    t.string "likeable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_at"], name: "index_likes_on_created_at"
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable"
    t.index ["user_id", "likeable_type", "likeable_id"], name: "index_likes_on_user_id_and_likeable_type_and_likeable_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "mastodon_oauth_applications", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "client_secret", null: false
    t.datetime "created_at", null: false
    t.string "server", null: false
    t.datetime "updated_at", null: false
    t.index ["server"], name: "index_mastodon_oauth_applications_on_server", unique: true
  end

  create_table "media_artwork_sources", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.text "provenance"
    t.datetime "retrieved_at", null: false
    t.string "source_hash", null: false
    t.text "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_id"], name: "index_media_artwork_sources_on_blob_id"
    t.index ["source_hash"], name: "index_media_artwork_sources_on_source_hash", unique: true
  end

  create_table "metadata_refreshes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.string "provider"
    t.json "provider_values", default: {}, null: false
    t.datetime "requested_at"
    t.string "state", default: "idle", null: false
    t.datetime "succeeded_at"
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_metadata_refreshes_on_item", unique: true
  end

  create_table "movies", force: :cascade do |t|
    t.string "api_id"
    t.datetime "created_at", null: false
    t.string "director"
    t.string "external_url"
    t.integer "release_year"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_movies_on_api_id"
    t.index ["created_at"], name: "index_movies_on_created_at"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "action"
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.integer "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "followed_id"
    t.integer "follower_id"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_relationships_on_created_at"
    t.index ["followed_id"], name: "index_relationships_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_relationships_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_relationships_on_follower_id"
  end

  create_table "steam_library_syncs", force: :cascade do |t|
    t.datetime "attempted_at"
    t.datetime "created_at", null: false
    t.integer "discovered", default: 0, null: false
    t.string "failure_reason"
    t.integer "imported", default: 0, null: false
    t.string "state", default: "never", null: false
    t.string "steam_id", null: false
    t.datetime "succeeded_at"
    t.integer "updated", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_steam_library_syncs_on_user_id", unique: true
  end

  create_table "tv_episodes", force: :cascade do |t|
    t.string "air_date"
    t.datetime "created_at", null: false
    t.integer "episode"
    t.string "name"
    t.string "rating"
    t.text "review"
    t.integer "season"
    t.text "summary"
    t.string "thumbnail_url"
    t.integer "tv_show_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "watched", default: false, null: false
    t.date "watched_at"
    t.index ["created_at"], name: "index_tv_episodes_on_created_at"
    t.index ["tv_show_id"], name: "index_tv_episodes_on_tv_show_id"
  end

  create_table "tv_shows", force: :cascade do |t|
    t.string "api_id"
    t.datetime "created_at", null: false
    t.string "external_url"
    t.string "network"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_tv_shows_on_api_id"
    t.index ["created_at"], name: "index_tv_shows_on_created_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "accent_theme", default: "violet", null: false
    t.boolean "admin", default: false
    t.string "avatar_url"
    t.text "bio"
    t.date "birthday"
    t.string "bsky_access_token"
    t.text "bsky_custom_message"
    t.string "bsky_did"
    t.string "bsky_handle"
    t.string "bsky_message_activity_template"
    t.string "bsky_message_review_template"
    t.boolean "bsky_post_activity", default: false, null: false
    t.boolean "bsky_post_reviews", default: false, null: false
    t.boolean "bsky_post_reviews_only"
    t.string "bsky_refresh_token"
    t.datetime "confirmed_at"
    t.string "content_density", default: "comfortable", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "mastodon_access_token"
    t.string "mastodon_message_activity_template"
    t.string "mastodon_message_review_template"
    t.boolean "mastodon_post_activity", default: false, null: false
    t.boolean "mastodon_post_reviews", default: false, null: false
    t.string "mastodon_refresh_token"
    t.string "mastodon_server"
    t.string "mastodon_uid"
    t.string "media_layout", default: "covers", null: false
    t.datetime "metadata_requested_at"
    t.string "name"
    t.boolean "notify_email_comments", default: true
    t.boolean "notify_email_follows", default: true
    t.boolean "notify_email_likes", default: true
    t.boolean "notify_email_posts", default: true
    t.boolean "notify_push_comments", default: true
    t.boolean "notify_push_follows", default: true
    t.boolean "notify_push_likes", default: true
    t.boolean "notify_push_posts", default: true
    t.string "password_digest"
    t.text "private_key"
    t.string "profile_accent", default: "violet", null: false
    t.string "profile_header", default: "linen", null: false
    t.text "public_key"
    t.boolean "reduce_effects", default: false, null: false
    t.string "theme", default: "os", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "video_games", force: :cascade do |t|
    t.string "api_id"
    t.datetime "created_at", null: false
    t.string "developer"
    t.string "external_url"
    t.string "game_type", default: "unknown", null: false
    t.json "metadata_details", default: {}, null: false
    t.string "platform"
    t.string "publisher"
    t.integer "release_year"
    t.text "synopsis"
    t.string "thumbnail_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_video_games_on_api_id"
    t.index ["created_at"], name: "index_video_games_on_created_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users", on_delete: :cascade
  add_foreign_key "comic_issues", "comics", on_delete: :cascade
  add_foreign_key "comments", "users", on_delete: :cascade
  add_foreign_key "edit_suggestions", "users"
  add_foreign_key "game_copies", "library_items"
  add_foreign_key "game_external_ids", "video_games"
  add_foreign_key "game_journal_entries", "library_items"
  add_foreign_key "game_library_views", "users"
  add_foreign_key "game_playthroughs", "library_items"
  add_foreign_key "game_sessions", "game_playthroughs"
  add_foreign_key "library_items", "users"
  add_foreign_key "likes", "users", on_delete: :cascade
  add_foreign_key "media_artwork_sources", "active_storage_blobs", column: "blob_id", on_delete: :cascade
  add_foreign_key "posts", "users"
  add_foreign_key "steam_library_syncs", "users"
  add_foreign_key "tv_episodes", "tv_shows", on_delete: :cascade
end
