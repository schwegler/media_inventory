# frozen_string_literal: true

class CreateEditSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :edit_suggestions do |t|
      t.references :suggestable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.json :proposed_changes
      t.text :admin_notes

      t.timestamps
    end
  end
end
