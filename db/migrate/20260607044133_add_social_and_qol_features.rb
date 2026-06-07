# frozen_string_literal: true

class AddSocialAndQolFeatures < ActiveRecord::Migration[8.1]
  def change
    # 1. Users table updates
    add_column :users, :private_key, :text
    add_column :users, :public_key, :text
    add_column :users, :bsky_handle, :string
    add_column :users, :bsky_app_password, :string
    add_column :users, :bsky_post_activity, :boolean, default: false, null: false
    add_column :users, :bsky_post_reviews, :boolean, default: false, null: false
    add_column :users, :bsky_message_activity_template, :string
    add_column :users, :bsky_message_review_template, :string

    # 2. TV Episodes table updates
    add_column :tv_episodes, :watched, :boolean, default: false, null: false
    add_column :tv_episodes, :watched_at, :date
    add_column :tv_episodes, :rating, :string
    add_column :tv_episodes, :review, :text

    # 3. Media tables updates (external_url)
    add_column :movies, :external_url, :string
    add_column :tv_shows, :external_url, :string
    add_column :albums, :external_url, :string
    add_column :comics, :external_url, :string
    add_column :wrestling_events, :external_url, :string

    # 4. Comments table
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :commentable, polymorphic: true, null: false
      t.text :content, null: false

      t.timestamps
    end
  end
end
