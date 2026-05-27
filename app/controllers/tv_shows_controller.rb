# frozen_string_literal: true

class TvShowsController < InventoryController
  private

  def resource_params
    params.require(:tv_show).permit(:title, :season, :episode, :network, :is_public)
  end
end
