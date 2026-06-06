# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :trackable, polymorphic: true, null: false
      t.string :activity_type, null: false
      t.text :details

      t.timestamps
    end

    add_index :activities, :created_at
  end
end
