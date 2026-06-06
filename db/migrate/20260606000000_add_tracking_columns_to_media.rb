# frozen_string_literal: true

class AddTrackingColumnsToMedia < ActiveRecord::Migration[8.1]
  def change
    tables = %i[movies albums comics tv_shows wrestling_events]

    tables.each do |table|
      add_column table, :thumbnail_url, :string
      add_column table, :in_watchlist, :boolean, default: false, null: false
      add_column table, :is_collected, :boolean, default: true, null: false
      add_column table, :consumed, :boolean, default: false, null: false
      add_column table, :consumed_at, :date
      add_column table, :review, :text

      # Add rating as a string if the table doesn't already have it
      add_column table, :rating, :string unless column_exists?(table, :rating)
    end
  end
end
