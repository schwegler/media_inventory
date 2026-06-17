# frozen_string_literal: true

class AddUniquenessToMediaItems < ActiveRecord::Migration[8.1]
  def change
    # TvShow
    add_index :tv_shows, %i[user_id api_id], unique: true, where: 'api_id IS NOT NULL'
    add_index :tv_shows, %i[user_id title], unique: true, where: 'api_id IS NULL'

    # Movie
    add_index :movies, %i[user_id api_id], unique: true, where: 'api_id IS NOT NULL'
    add_index :movies, %i[user_id title release_year], unique: true, where: 'api_id IS NULL'

    # Album
    add_index :albums, %i[user_id api_id], unique: true, where: 'api_id IS NOT NULL'
    add_index :albums, %i[user_id title artist], unique: true, where: 'api_id IS NULL'

    # Comic
    add_index :comics, %i[user_id api_id], unique: true, where: 'api_id IS NOT NULL'
    add_index :comics, %i[user_id title issue_number], unique: true, where: 'api_id IS NULL'

    # VideoGame
    add_index :video_games, %i[user_id api_id], unique: true, where: 'api_id IS NOT NULL'
    add_index :video_games, %i[user_id title platform], unique: true, where: 'api_id IS NULL'
  end
end
