# frozen_string_literal: true

class AddSavedShelfPresentation < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :shelf_presentation, :json, null: false, default: {}
  end
end
