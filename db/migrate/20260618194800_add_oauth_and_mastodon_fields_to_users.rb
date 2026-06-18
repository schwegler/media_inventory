class AddOauthAndMastodonFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :mastodon_oauth_applications do |t|
      t.string :server, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false

      t.timestamps
    end
    add_index :mastodon_oauth_applications, :server, unique: true

    add_column :users, :mastodon_server, :string
    add_column :users, :mastodon_uid, :string
    add_column :users, :mastodon_access_token, :string
    add_column :users, :mastodon_refresh_token, :string
    add_column :users, :mastodon_post_activity, :boolean, default: false, null: false
    add_column :users, :mastodon_post_reviews, :boolean, default: false, null: false
    add_column :users, :mastodon_message_activity_template, :string
    add_column :users, :mastodon_message_review_template, :string

    add_column :users, :bsky_access_token, :string
    add_column :users, :bsky_refresh_token, :string
    add_column :users, :bsky_did, :string

    remove_column :users, :bsky_app_password, :string
  end
end
