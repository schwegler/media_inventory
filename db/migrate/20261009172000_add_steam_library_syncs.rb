# frozen_string_literal: true

class AddSteamLibrarySyncs < ActiveRecord::Migration[8.1]
  def change
    add_column :game_copies, :steam_app_id, :string
    add_column :game_copies, :imported_playtime_minutes, :integer
    add_index :game_copies, %i[library_item_id steam_app_id], unique: true
    create_table :steam_library_syncs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :steam_id, null: false
      t.string :state, default: 'never', null: false
      t.datetime :attempted_at
      t.datetime :succeeded_at
      t.integer :discovered, default: 0, null: false
      t.integer :imported, default: 0, null: false
      t.integer :updated, default: 0, null: false
      t.string :failure_reason
      t.timestamps
    end
  end
end
