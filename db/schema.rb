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

ActiveRecord::Schema[8.1].define(version: 2026_06_07_071040) do
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
    t.string "artist"
    t.boolean "consumed", default: false, null: false
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.string "genre"
    t.boolean "in_watchlist", default: false, null: false
    t.boolean "is_collected", default: true, null: false
    t.boolean "is_public", default: false
    t.string "rating"
    t.integer "release_year"
    t.text "review"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_albums_on_user_id"
  end

  create_table "comics", force: :cascade do |t|
    t.string "artist"
    t.boolean "consumed", default: false, null: false
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.boolean "in_watchlist", default: false, null: false
    t.boolean "is_collected", default: true, null: false
    t.boolean "is_public", default: false
    t.integer "issue_number"
    t.string "publisher"
    t.string "rating"
    t.text "review"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "writer"
    t.index ["user_id"], name: "index_comics_on_user_id"
  end

  create_table "movies", force: :cascade do |t|
    t.boolean "consumed", default: false, null: false
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.string "director"
    t.boolean "in_watchlist", default: false, null: false
    t.boolean "is_collected", default: true, null: false
    t.boolean "is_public", default: false
    t.string "rating"
    t.integer "release_year"
    t.text "review"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_movies_on_user_id"
  end

  create_table "tv_shows", force: :cascade do |t|
    t.boolean "consumed", default: false, null: false
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.integer "episode"
    t.boolean "in_watchlist", default: false, null: false
    t.boolean "is_collected", default: true, null: false
    t.boolean "is_public", default: false
    t.string "network"
    t.string "rating"
    t.text "review"
    t.integer "season"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_tv_shows_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.string "bsky_app_password"
    t.text "bsky_custom_message"
    t.string "bsky_handle"
    t.boolean "bsky_post_reviews_only"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wrestling_events", force: :cascade do |t|
    t.boolean "consumed", default: false, null: false
    t.date "consumed_at"
    t.datetime "created_at", null: false
    t.date "date"
    t.boolean "in_watchlist", default: false, null: false
    t.boolean "is_collected", default: true, null: false
    t.boolean "is_public", default: false
    t.string "promotion"
    t.string "rating"
    t.text "review"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "venue"
    t.index ["user_id"], name: "index_wrestling_events_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users", on_delete: :cascade
  add_foreign_key "albums", "users", on_delete: :cascade
  add_foreign_key "comics", "users", on_delete: :cascade
  add_foreign_key "movies", "users", on_delete: :cascade
  add_foreign_key "tv_shows", "users", on_delete: :cascade
  add_foreign_key "wrestling_events", "users", on_delete: :cascade
end
