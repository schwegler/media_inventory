# frozen_string_literal: true

class AddCascadeDeleteToUsers < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :albums, :users
    remove_foreign_key :comics, :users
    remove_foreign_key :movies, :users
    remove_foreign_key :tv_shows, :users
    remove_foreign_key :wrestling_events, :users

    add_foreign_key :albums, :users, on_delete: :cascade
    add_foreign_key :comics, :users, on_delete: :cascade
    add_foreign_key :movies, :users, on_delete: :cascade
    add_foreign_key :tv_shows, :users, on_delete: :cascade
    add_foreign_key :wrestling_events, :users, on_delete: :cascade
  end
end
