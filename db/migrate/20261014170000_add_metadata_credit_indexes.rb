# frozen_string_literal: true

class AddMetadataCreditIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :metadata_credits, %i[role item_type metadata_entity_id], name: 'idx_credits_role_type_entity'
    add_index :metadata_credits, %i[item_type metadata_entity_id], name: 'idx_credits_type_entity'
  end
end
