# frozen_string_literal: true

class PersistMediaArtworkSources < ActiveRecord::Migration[8.1]
  def change
    create_table :media_artwork_sources do |t|
      t.string :source_hash, null: false
      t.text :source_url, null: false
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs, on_delete: :cascade }
      t.datetime :retrieved_at, null: false
      t.text :provenance
      t.timestamps
    end
    add_index :media_artwork_sources, :source_hash, unique: true
  end
end
