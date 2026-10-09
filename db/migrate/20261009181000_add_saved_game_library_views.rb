# frozen_string_literal: true

class AddSavedGameLibraryViews < ActiveRecord::Migration[8.1]
  def change
    create_table :game_library_views do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.json :filters, null: false, default: {}
      t.timestamps
    end
    add_index :game_library_views, %i[user_id name], unique: true
  end
end
