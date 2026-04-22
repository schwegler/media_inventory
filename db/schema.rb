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

ActiveRecord::Schema[7.2].define(version: 2026_04_22_171128) do
  create_table "albums", force: :cascade do |t|
    t.string "title"
    t.string "artist"
    t.integer "release_year"
    t.string "genre"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_albums_on_user_id"
  end

  create_table "comics", force: :cascade do |t|
    t.string "title"
    t.integer "issue_number"
    t.string "publisher"
    t.string "writer"
    t.string "artist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_comics_on_user_id"
  end

  create_table "movies", force: :cascade do |t|
    t.string "title"
    t.string "director"
    t.integer "release_year"
    t.string "rating"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_movies_on_user_id"
  end

  create_table "tv_shows", force: :cascade do |t|
    t.string "title"
    t.integer "season"
    t.integer "episode"
    t.string "network"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_tv_shows_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "login_token"
    t.datetime "login_token_sent_at"
    t.datetime "confirmed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wrestling_events", force: :cascade do |t|
    t.string "title"
    t.string "promotion"
    t.date "date"
    t.string "venue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_wrestling_events_on_user_id"
  end

  add_foreign_key "albums", "users"
  add_foreign_key "comics", "users"
  add_foreign_key "movies", "users"
  add_foreign_key "tv_shows", "users"
  add_foreign_key "wrestling_events", "users"
end
