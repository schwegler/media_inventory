# frozen_string_literal: true

class ExpandPersonalGameRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :game_copies, :acquisition_source, :string
    add_column :game_copies, :gifted, :boolean, null: false, default: false
    add_column :game_copies, :condition, :string
    add_column :game_copies, :region, :string
    add_column :game_sessions, :enjoyment, :integer
    add_column :game_sessions, :mood, :string
    add_column :game_sessions, :progress, :integer
    add_column :library_items, :game_favorite, :boolean, null: false, default: false
    add_column :library_items, :game_tags, :json, null: false, default: []
    add_column :library_items, :game_activity_public, :boolean, null: false, default: false
    create_table :game_milestones do |t|
      t.references :library_item, null: false, foreign_key: true
      t.references :game_playthrough, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.datetime :completed_at
      t.boolean :spoiler, null: false, default: false
      t.timestamps
    end
  end
end
