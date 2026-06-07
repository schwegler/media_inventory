# frozen_string_literal: true

class CreateSeriesEpisodesAndIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :tv_shows, :api_id, :string
    add_column :comics, :api_id, :string
    add_column :movies, :api_id, :string
    add_column :albums, :api_id, :string
    add_column :wrestling_events, :api_id, :string

    create_table :tv_episodes do |t|
      t.references :tv_show, null: false, foreign_key: { on_delete: :cascade }
      t.string :name
      t.integer :season
      t.integer :episode
      t.string :air_date
      t.text :summary
      t.string :thumbnail_url

      t.timestamps
    end

    create_table :comic_issues do |t|
      t.references :comic, null: false, foreign_key: { on_delete: :cascade }
      t.string :title
      t.string :release_date
      t.string :publisher
      t.string :thumbnail_url

      t.timestamps
    end
  end
end
