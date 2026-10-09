# frozen_string_literal: true

class AddGameMetadataDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :video_games, :synopsis, :text
    add_column :video_games, :metadata_details, :json, default: {}, null: false
  end
end
