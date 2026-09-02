# frozen_string_literal: true

class CollectionsController < ApplicationController
  # OPTIMIZATION: Eager load polymorphic `:item` association and inner join media tables for search.
  # PERFORMANCE IMPACT: Reduces database query count from 1 + 5*N (N+1 queries for each collection item)
  # to a constant 5 queries (1 per media type). When search query is present, enables safe database-level
  # filtering on media titles without triggering SQL "no such column: title" errors.
  def show
    @user = User.find(params[:user_id])
    @query = params[:q]

    if @user.confirmed_at.present?
      load_user_collections
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end

  private

  def load_user_collections
    # Preload the polymorphic `:item` association to avoid N+1 queries in collections view
    @albums = fetch_collection_scope('Album', 'albums')
    @comics = fetch_collection_scope('Comic', 'comics')
    @movies = fetch_collection_scope('Movie', 'movies')
    @tv_shows = fetch_collection_scope('TvShow', 'tv_shows')
    @video_games = fetch_collection_scope('VideoGame', 'video_games')
  end

  def fetch_collection_scope(item_type, table_name)
    scope = @user.library_items.includes(:item).where(item_type: item_type, is_public: true)
    return scope if @query.blank?

    # Join corresponding media table for database-level title search filtering using Arel to prevent SQL injection warnings
    join_clause = sanitize_join_sql(table_name)
    media_table = Arel::Table.new(table_name)
    scope.joins(join_clause).where(media_table[:title].matches("%#{@query}%"))
  end

  def sanitize_join_sql(table_name)
    # Map allowed table names to fixed, safe join SQL strings to avoid dynamic interpolation
    join_sqls = {
      'albums' => "INNER JOIN albums ON albums.id = library_items.item_id AND library_items.item_type = 'Album'",
      'comics' => "INNER JOIN comics ON comics.id = library_items.item_id AND library_items.item_type = 'Comic'",
      'movies' => "INNER JOIN movies ON movies.id = library_items.item_id AND library_items.item_type = 'Movie'",
      'tv_shows' => "INNER JOIN tv_shows ON tv_shows.id = library_items.item_id AND library_items.item_type = 'TvShow'",
      'video_games' => 'INNER JOIN video_games ON video_games.id = library_items.item_id AND ' \
                       "library_items.item_type = 'VideoGame'"
    }
    join_sqls[table_name]
  end
end
