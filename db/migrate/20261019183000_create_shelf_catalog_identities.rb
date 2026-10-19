# frozen_string_literal: true

class CreateShelfCatalogIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :shelf_catalog_identities do |t|
      t.string :media_type, null: false
      t.string :identity_key, null: false, limit: 64
      t.text :provider_id, null: false
      t.timestamps
    end
    add_index :shelf_catalog_identities, %i[media_type identity_key], unique: true
  end
end
