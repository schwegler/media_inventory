# frozen_string_literal: true

class AlbumsController < InventoryController
  private

  def resource_params
    params.require(:album).permit(:title, :artist, :release_year, :genre, :is_public)
  end
end
