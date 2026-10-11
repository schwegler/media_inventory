# frozen_string_literal: true

class AddRichDetailsToMoviesAndTvShows < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :writer, :string
    add_column :movies, :actors, :text
    add_column :movies, :genre, :string
    add_index :movies, :genre
    add_index :movies, :director

    add_column :tv_shows, :director, :string
    add_column :tv_shows, :writer, :string
    add_column :tv_shows, :actors, :text
    add_column :tv_shows, :genre, :string
    add_column :tv_shows, :release_year, :integer
    add_index :tv_shows, :genre
    add_index :tv_shows, :release_year
  end
end
