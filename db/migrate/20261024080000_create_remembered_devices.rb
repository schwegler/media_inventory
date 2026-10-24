# frozen_string_literal: true

class CreateRememberedDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :session_generation, :integer, default: 0, null: false
    create_table :remembered_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :session_generation, null: false
      t.string :token_digest, null: false
      t.string :previous_token_digest
      t.datetime :rotated_at
      t.datetime :expires_at, null: false
      t.timestamps
    end
  end
end
