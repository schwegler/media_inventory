# frozen_string_literal: true

class WrestlingEventsController < InventoryController
  private

  def resource_params
    params.require(:wrestling_event).permit(
      :title, :promotion, :date, :venue, :is_public, :thumbnail_url, :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id, :external_url
    )
  end
end
