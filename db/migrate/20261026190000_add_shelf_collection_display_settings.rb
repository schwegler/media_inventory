# frozen_string_literal: true

class AddShelfCollectionDisplaySettings < ActiveRecord::Migration[8.1]
  def change
    add_column :shelf_collections, :allowed_media_types, :json, null: false, default: []
    add_column :shelf_collections, :preview_length, :integer, null: false, default: 5
  end
end
