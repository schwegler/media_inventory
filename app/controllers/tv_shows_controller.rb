# frozen_string_literal: true

class TvShowsController < InventoryController
  def new
    @tv_show = TvShow.new
  end

  private

  def resource_params
    params.require(:tv_show).permit(
      :title, :season, :episode, :network, :is_public, :thumbnail_url, :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id, :external_url
    )
  end
end
