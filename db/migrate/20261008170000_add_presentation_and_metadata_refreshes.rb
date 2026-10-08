# frozen_string_literal: true

class AddPresentationAndMetadataRefreshes < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :accent_theme, :string, default: 'violet', null: false
    add_column :users, :content_density, :string, default: 'comfortable', null: false
    add_column :users, :media_layout, :string, default: 'covers', null: false
    add_column :users, :reduce_effects, :boolean, default: false, null: false
    add_column :users, :profile_accent, :string, default: 'violet', null: false
    add_column :users, :profile_header, :string, default: 'linen', null: false
    add_column :users, :metadata_requested_at, :datetime
    add_column :comic_issues, :provider_id, :string
    add_index :comic_issues, %i[comic_id provider_id], unique: true

    create_table :metadata_refreshes do |t|
      t.references :item, polymorphic: true, null: false, index: { unique: true }
      t.string :provider
      t.string :state, default: 'idle', null: false
      t.datetime :requested_at
      t.datetime :succeeded_at
      t.json :provider_values, default: {}, null: false
      t.timestamps
    end
  end
end
