# frozen_string_literal: true

class MoviesController < InventoryController
  before_action :logged_in_user, only: %i[new create]

  def index
    @movies = Movie.page(params[:page])
  end

  def show
    @movie = Movie.find(params[:id])
  end

  private

  def movie_params
    params.require(:movie).permit(:title, :director, :release_year, :rating)
  end

  def resource_params
    movie_params
  end
end
