# frozen_string_literal: true

class CollectionsController < ApplicationController
  def show
    @user = User.find(params[:user_id])
    @query = params[:q]

    if @user.confirmed_at.present?
      @albums = @user.albums.where(is_public: true)
      @comics = @user.comics.where(is_public: true)
      @movies = @user.movies.where(is_public: true)
      @tv_shows = @user.tv_shows.where(is_public: true)
      @video_games = @user.video_games.where(is_public: true)
      
      if @query.present?
        search_term = "%#{@query}%"
        @albums = @albums.where("title LIKE ?", search_term)
        @comics = @comics.where("title LIKE ?", search_term)
        @movies = @movies.where("title LIKE ?", search_term)
        @tv_shows = @tv_shows.where("title LIKE ?", search_term)
        @video_games = @video_games.where("title LIKE ?", search_term)
      end
    else
      @albums = @comics = @movies = @tv_shows = @video_games = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end
end
