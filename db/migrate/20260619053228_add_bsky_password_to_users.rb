class AddBskyPasswordToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :bsky_password, :string
  end
end
