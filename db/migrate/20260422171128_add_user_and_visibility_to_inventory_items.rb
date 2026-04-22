# frozen_string_literal: true

class AddUserAndVisibilityToInventoryItems < ActiveRecord::Migration[7.1]
  def change
    %i[albums comics movies tv_shows wrestling_events].each do |table|
      add_reference table, :user, null: true, foreign_key: true
      add_column table, :is_public, :boolean, default: false
    end
  end
end
