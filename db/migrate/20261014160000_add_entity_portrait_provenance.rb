# frozen_string_literal: true

class AddEntityPortraitProvenance < ActiveRecord::Migration[8.1]
  def change
    add_column :metadata_entities, :portrait_checked_at, :datetime
    add_column :metadata_entities, :portrait_metadata, :json, default: {}, null: false
  end
end
