# frozen_string_literal: true

class CreateApiConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :api_configurations do |t|
      t.string :source_name
      t.string :media_type
      t.boolean :is_active
      t.string :access_token
      t.string :base_url
      t.text :options

      t.timestamps
    end
  end
end
