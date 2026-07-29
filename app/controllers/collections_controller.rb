# frozen_string_literal: true

class CollectionsController < ApplicationController
  def show
    @user = User.find(params[:user_id])
    @query = params[:q]

    if @user.confirmed_at.present?
      search_term = @query.present? ? "%#{@query}%" : nil

      # Performance optimization:
      # 1. Eager load the polymorphic `:item` association to prevent N+1 queries during view rendering.
      # 2. Perform SQL-level filtering by joining on the specific media tables, plucking matching IDs
      #    first, and then loading full records. This avoids ActiveRecord::EagerLoadPolymorphicError.
      @albums = fetch_collection_items('Album', 'albums', search_term)
      @comics = fetch_collection_items('Comic', 'comics', search_term)
      @movies = fetch_collection_items('Movie', 'movies', search_term)
      @tv_shows = fetch_collection_items('TvShow', 'tv_shows', search_term)
      @video_games = fetch_collection_items('VideoGame', 'video_games', search_term)
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end

  private

  def fetch_collection_items(item_type, table_name, search_term)
    scope = @user.library_items.where(item_type: item_type, is_public: true)

    if search_term.present?
      # Inner join respective media tables when search queries are present to enable safe,
      # database-level filtering and prevent SQLite missing column errors or eager-loading errors.
      matching_ids = scope.joins("INNER JOIN #{table_name} ON #{table_name}.id = library_items.item_id")
                          .where("#{table_name}.title LIKE ?", search_term)
                          .pluck(:id)
      @user.library_items.where(id: matching_ids).includes(:item)
    else
      scope.includes(:item)
    end
  end
end
