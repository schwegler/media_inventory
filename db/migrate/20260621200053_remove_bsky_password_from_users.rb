# frozen_string_literal: true

class RemoveBskyPasswordFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :bsky_app_password, :string
    remove_column :users, :bsky_password, :string
  end
end
