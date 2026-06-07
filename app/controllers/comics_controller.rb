# frozen_string_literal: true

class ComicsController < InventoryController
  private

  def resource_params
    params.require(:comic).permit(
      :title, :issue_number, :publisher, :writer, :artist, :is_public, :thumbnail_url,
      :in_watchlist, :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id
    )
  end
end
