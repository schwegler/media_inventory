# frozen_string_literal: true

class CreateFavoriteShelves < ActiveRecord::Migration[8.0]
  def change
    create_table :favorite_shelves do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category, null: false
      t.json :picks, null: false, default: []
      t.timestamps
    end
    add_index :favorite_shelves, %i[user_id category], unique: true
  end
end
