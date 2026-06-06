# frozen_string_literal: true

class CreateSeriesEpisodesAndIssues < ActiveRecord::Migration[8.1]
  # rubocop:disable Metrics/MethodLength
  def change
    add_column :tv_shows, :api_id, :string
    add_column :comics, :api_id, :string

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
  # rubocop:enable Metrics/MethodLength
end
