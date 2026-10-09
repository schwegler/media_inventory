# frozen_string_literal: true

class AddTypedGameArtworkAndRenditions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_artworks do |t|
      t.references :video_game, null: false, foreign_key: true
      t.references :library_item, foreign_key: true
      t.string :kind, null: false
      t.string :provider
      t.string :source_url
      t.string :author
      t.string :attribution_url
      t.string :platform
      t.string :edition
      t.timestamps
    end
    create_table :game_artwork_batches do |t|
      t.references :video_game, null: false, foreign_key: true, index: { unique: true }
      t.string :state, null: false, default: 'idle'
      t.datetime :requested_at
      t.string :failure_reason
      t.timestamps
    end
    create_table :media_artwork_renditions do |t|
      t.bigint :source_blob_id, null: false
      t.bigint :blob_id
      t.integer :requested_width, null: false
      t.integer :requested_height, null: false
      t.integer :width
      t.integer :height
      t.string :state, null: false, default: 'pending'
      t.string :failure_reason
      t.timestamps
    end
    add_foreign_key :media_artwork_renditions, :active_storage_blobs, column: :source_blob_id, on_delete: :cascade
    add_foreign_key :media_artwork_renditions, :active_storage_blobs, column: :blob_id, on_delete: :cascade
    add_index :media_artwork_renditions, %i[source_blob_id requested_width requested_height],
              unique: true, name: :index_artwork_renditions_on_source_and_size
  end
end
