# frozen_string_literal: true

class TrackCoverImportHealth < ActiveRecord::Migration[8.1]
  def change
    create_table :cover_imports do |t|
      t.references :item, polymorphic: true, null: false
      t.string :source_url, null: false
      t.string :state, default: 'pending', null: false
      t.integer :attempts, default: 0, null: false
      t.string :failure_reason
      t.datetime :attempted_at
      t.datetime :ready_at
      t.timestamps
    end
    add_index :cover_imports, %i[item_type item_id], unique: true, name: 'unique_cover_import_item'
    add_index :cover_imports, %i[state attempted_at]
  end
end
