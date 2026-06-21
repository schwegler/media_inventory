# frozen_string_literal: true

class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title
      t.string :author
      t.string :publisher
      t.integer :release_year
      t.string :api_id
      t.string :external_url
      t.string :thumbnail_url

      t.timestamps
    end
  end
end
