# frozen_string_literal: true

class AddAdminOperationalIndexes < ActiveRecord::Migration[8.1]
  def change
    %i[users library_items comments likes relationships movies tv_shows tv_episodes video_games books
       comics comic_issues albums].each do |table|
      add_index table, :created_at
    end
    add_index :edit_suggestions, %i[status created_at]
  end
end
