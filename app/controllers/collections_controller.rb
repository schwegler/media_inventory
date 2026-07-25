# frozen_string_literal: true

class CollectionsController < ApplicationController
  # rubocop:disable Metrics/AbcSize
  def show
    @user = User.find(params[:user_id])
    @query = params[:q]

    if @user.confirmed_at.present?
      # Eager load polymorphic :item to completely eliminate N+1 query bottlenecks (O(1) queries instead of O(N))
      @albums = @user.albums.where(is_public: true).includes(:item)
      @comics = @user.comics.where(is_public: true).includes(:item)
      @movies = @user.movies.where(is_public: true).includes(:item)
      @tv_shows = @user.tv_shows.where(is_public: true).includes(:item)
      @video_games = @user.video_games.where(is_public: true).includes(:item)

      if @query.present?
        search_term = "%#{@query}%"
        # Join underlying media tables to allow safe, database-level filtering on item title
        @albums = @albums.joins('INNER JOIN albums ON albums.id = library_items.item_id')
                         .where('albums.title LIKE ?', search_term)
        @comics = @comics.joins('INNER JOIN comics ON comics.id = library_items.item_id')
                         .where('comics.title LIKE ?', search_term)
        @movies = @movies.joins('INNER JOIN movies ON movies.id = library_items.item_id')
                         .where('movies.title LIKE ?', search_term)
        @tv_shows = @tv_shows.joins('INNER JOIN tv_shows ON tv_shows.id = library_items.item_id')
                             .where('tv_shows.title LIKE ?', search_term)
        @video_games = @video_games.joins('INNER JOIN video_games ON video_games.id = library_items.item_id')
                                   .where('video_games.title LIKE ?', search_term)
      end
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end
  # rubocop:enable Metrics/AbcSize
end
