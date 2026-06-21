# frozen_string_literal: true

class BooksController < InventoryController
  before_action :logged_in_user, only: %i[new create]


  private

  def resource_params
    params.require(:book).permit(
      :title, :author, :release_year, :publisher, :rating, :is_public, :thumbnail_url, :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :cover_image, :api_id, :external_url,
      :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format
    )
  end
end
