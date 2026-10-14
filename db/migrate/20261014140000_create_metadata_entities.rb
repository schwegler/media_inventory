# frozen_string_literal: true

class CreateMetadataEntities < ActiveRecord::Migration[8.1]
  def change
    create_entities
    create_relationships
    create_tracks
    extend_media
  end

  private

  def create_entities
    create_table :metadata_entities do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :identity_key, null: false
      t.string :slug, null: false
      t.json :aliases, default: [], null: false
      t.text :description
      t.string :thumbnail_url
      t.timestamps
    end
    add_index :metadata_entities, :identity_key, unique: true
    add_index :metadata_entities, %i[kind normalized_name]
    add_index :metadata_entities, :normalized_name
  end

  def create_relationships
    create_table :metadata_identities do |t|
      t.references :metadata_entity, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :external_id, null: false
      t.timestamps
    end
    add_index :metadata_identities, %i[provider external_id], unique: true
    create_table :metadata_credits do |t|
      t.references :metadata_entity, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.string :role, null: false
      t.string :source, null: false
      t.integer :position, default: 0, null: false
      t.json :details, default: {}, null: false
      t.timestamps
    end
    add_index :metadata_credits, %i[item_type item_id metadata_entity_id role source], unique: true,
                                                                                       name: 'idx_metadata_credit_identity'
    add_index :metadata_credits, %i[role metadata_entity_id]
  end

  def create_tracks
    create_table :album_tracks do |t|
      t.references :album, null: false, foreign_key: true
      t.string :provider_id, null: false
      t.string :title, null: false
      t.integer :disc_number
      t.integer :track_number
      t.integer :duration_ms
      t.string :isrc
      t.string :content_rating
      t.string :release_date
      t.json :credits, default: [], null: false
      t.timestamps
    end
    add_index :album_tracks, %i[album_id provider_id], unique: true
    add_index :album_tracks, %i[album_id disc_number track_number]
  end

  def extend_media
    %i[movies tv_shows albums comics books video_games].each do |table|
      add_column table, :metadata_credits_data, :json, default: [], null: false
      add_column table, :metadata_details, :json, default: {}, null: false unless table == :video_games
    end
  end
end
