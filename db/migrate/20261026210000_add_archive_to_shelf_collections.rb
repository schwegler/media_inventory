# frozen_string_literal: true

class AddArchiveToShelfCollections < ActiveRecord::Migration[8.1]
  def up
    add_column :shelf_collections, :archived_at, :datetime
  end

  def down
    if select_value('SELECT 1 FROM shelf_collections WHERE archived_at IS NOT NULL LIMIT 1')
      raise ActiveRecord::IrreversibleMigration,
            'Archived shelves exist. Review their restoration before removing archive protection.'
    end
    remove_column :shelf_collections, :archived_at
  end
end
