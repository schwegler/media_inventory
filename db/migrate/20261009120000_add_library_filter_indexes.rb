# frozen_string_literal: true

class AddLibraryFilterIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :library_items, %i[user_id is_collected created_at]
    add_index :library_items, %i[user_id in_backlog created_at]
    add_index :library_items, %i[user_id is_public item_type created_at], name: 'index_library_items_on_public_catalog'
    %i[movies tv_shows albums books comics video_games].each { |table| add_index table, :api_id }
  end
end
