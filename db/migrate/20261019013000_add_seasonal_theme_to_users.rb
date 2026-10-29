# frozen_string_literal: true

class AddSeasonalThemeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :seasonal_theme, :string, default: 'off', null: false
  end
end
