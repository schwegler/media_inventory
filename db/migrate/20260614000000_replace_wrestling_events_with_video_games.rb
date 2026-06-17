# frozen_string_literal: true

class ReplaceWrestlingEventsWithVideoGames < ActiveRecord::Migration[8.1]
  def change
    # Drop wrestling_events table
    drop_table :wrestling_events, if_exists: true do |t|
      t.string :api_id
      t.boolean :consumed, default: false, null: false
      t.date :consumed_at
      t.date :date
      t.string :external_url
      t.boolean :in_watchlist, default: false, null: false
      t.boolean :is_collected, default: true, null: false
      t.boolean :is_public, default: false
      t.string :promotion
      t.string :rating
      t.text :review
      t.string :thumbnail_url
      t.string :title
      t.integer :user_id
      t.string :venue
      t.timestamps
    end

    # Clean up any comments and activities referencing WrestlingEvent
    reversible do |dir|
      dir.up do
        execute "DELETE FROM activities WHERE trackable_type = 'WrestlingEvent'"
        execute "DELETE FROM comments WHERE commentable_type = 'WrestlingEvent'"
      end
    end

    # Create video_games table
    create_table :video_games do |t|
      t.string :title, null: false
      t.string :developer
      t.string :publisher
      t.string :platform
      t.integer :release_year
      t.string :rating
      t.boolean :is_public, default: false, null: false
      t.string :thumbnail_url
      t.boolean :in_watchlist, default: false, null: false
      t.boolean :is_collected, default: true, null: false
      t.boolean :consumed, default: false, null: false
      t.date :consumed_at
      t.text :review
      t.string :api_id
      t.string :external_url
      t.references :user, null: true, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
