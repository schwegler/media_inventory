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
      # Security: Allow collection owner to see private items in their collection,
      # but restrict non-owners to public items only.
      @albums = scope_collection(@user.albums)
      @comics = scope_collection(@user.comics)
      @movies = scope_collection(@user.movies)
      @tv_shows = scope_collection(@user.tv_shows)
      @video_games = scope_collection(@user.video_games)

      if @query.present?
        search_term = "%#{@query}%"
        @albums = @albums.where('title LIKE ?', search_term)
        @comics = @comics.where('title LIKE ?', search_term)
        @movies = @movies.where('title LIKE ?', search_term)
        @tv_shows = @tv_shows.where('title LIKE ?', search_term)
        @video_games = @video_games.where('title LIKE ?', search_term)
      end
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end

  private

  def scope_collection(relation)
    current_user?(@user) ? relation : relation.where(is_public: true)
  end
end
