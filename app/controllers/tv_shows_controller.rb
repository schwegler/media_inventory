# frozen_string_literal: true

class TvShowsController < InventoryController
  def index
    @tv_shows = TvShow.page(params[:page])
  end

  def new
    @tv_show = TvShow.new
  end

  private

  def resource_params
    params.require(:tv_show).permit(:title, :season, :episode, :network)
  end
end
