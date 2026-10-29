# frozen_string_literal: true

class CreateShelfCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :shelf_collections do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :slug, null: false
      t.string :title, null: false
      t.string :description
      t.json :picks, null: false, default: []
      t.json :presentation, null: false, default: {}
      t.timestamps
    end
    add_index :shelf_collections, %i[user_id slug], unique: true
  end
end
