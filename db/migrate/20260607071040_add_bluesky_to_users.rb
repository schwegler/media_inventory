class AddBlueskyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :bsky_handle, :string
    add_column :users, :bsky_app_password, :string
    add_column :users, :bsky_post_reviews_only, :boolean
    add_column :users, :bsky_custom_message, :text
  end
end
