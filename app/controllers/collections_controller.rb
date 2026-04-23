# frozen_string_literal: true

class CollectionsController < ApplicationController
  def show
    @user = User.find(params[:user_id])

    if @user.confirmed_at.present?
      @albums = @user.albums.where(is_public: true)
      @comics = @user.comics.where(is_public: true)
      @movies = @user.movies.where(is_public: true)
      @tv_shows = @user.tv_shows.where(is_public: true)
      @wrestling_events = @user.wrestling_events.where(is_public: true)
    else
      @albums = @comics = @movies = @tv_shows = @wrestling_events = []
      flash.now[:warning] = "This user's collection is not public because their account is unconfirmed."
    end
  end
end
