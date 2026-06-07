# frozen_string_literal: true

class AlbumsController < InventoryController
  private

  def resource_params
    params.require(:album).permit(:title, :artist, :release_year, :genre, :is_public, :thumbnail_url, :in_watchlist,
                                  :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id)
  end
end
