# frozen_string_literal: true

class CollectionsController < ApplicationController
  def show
    @user = User.find(params[:user_id])
    @query = params[:q]

    if @user.confirmed_at.present?
      # Bolt Optimization: Eager load polymorphic :item to prevent N+1 queries when rendering collection items
      @albums = @user.albums.includes(:item).where(is_public: true)
      @comics = @user.comics.includes(:item).where(is_public: true)
      @movies = @user.movies.includes(:item).where(is_public: true)
      @tv_shows = @user.tv_shows.includes(:item).where(is_public: true)
      @video_games = @user.video_games.includes(:item).where(is_public: true)

      if @query.present?
        search_term = "%#{@query}%"
        # Explicit INNER JOINs on media tables to enable safe database-level filtering on item title
        @albums = filter_collection(@albums, 'albums', 'Album', search_term)
        @comics = filter_collection(@comics, 'comics', 'Comic', search_term)
        @movies = filter_collection(@movies, 'movies', 'Movie', search_term)
        @tv_shows = filter_collection(@tv_shows, 'tv_shows', 'TvShow', search_term)
        @video_games = filter_collection(@video_games, 'video_games', 'VideoGame', search_term)
      end
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end

  private

  def filter_collection(scope, table_name, type_name, search_term)
    join_sql = "INNER JOIN #{table_name} ON library_items.item_id = #{table_name}.id " \
               "AND library_items.item_type = '#{type_name}'"
    scope.joins(join_sql).where("#{table_name}.title LIKE ?", search_term)
  end
end
