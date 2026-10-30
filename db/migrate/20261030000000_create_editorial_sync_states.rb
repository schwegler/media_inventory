# frozen_string_literal: true

class CreateEditorialSyncStates < ActiveRecord::Migration[8.1]
  def change
    create_table :editorial_sync_states do |t|
      t.string :name, null: false
      t.datetime :watermark
      t.datetime :window_after
      t.datetime :window_before
      t.integer :next_page, null: false, default: 1
      t.integer :per_page
      t.string :lease_token
      t.datetime :lease_until
      t.timestamps
    end
    add_index :editorial_sync_states, :name, unique: true
  end
end
