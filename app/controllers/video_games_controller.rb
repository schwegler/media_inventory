# frozen_string_literal: true

class VideoGamesController < InventoryController
  before_action :logged_in_user, only: %i[new create]

  def index
    @video_games = VideoGame.page(params[:page])
  end

  def show
    @video_game = VideoGame.find(params[:id])
  end

  private

  def resource_params
    params.require(:video_game).permit(
      :title, :developer, :publisher, :platform, :release_year, :rating, :is_public, :thumbnail_url, :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :cover_image, :api_id, :external_url
    )
  end
end
