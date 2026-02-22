# frozen_string_literal: true

class AlbumsController < InventoryController
  private

  def album_params
    params.require(:album).permit(:title, :artist, :release_year, :genre)
  end

  def resource_params
    album_params
  end
end
