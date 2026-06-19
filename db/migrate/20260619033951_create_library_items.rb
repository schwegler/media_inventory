# frozen_string_literal: true

class CreateLibraryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :library_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.boolean :is_collected
      t.boolean :in_backlog
      t.string :rating
      t.text :review
      t.boolean :consumed
      t.date :consumed_at
      t.boolean :is_public

      t.timestamps
    end
  end
end
