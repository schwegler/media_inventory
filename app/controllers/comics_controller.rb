# frozen_string_literal: true

class ComicsController < InventoryController
  before_action :logged_in_user, only: %i[new create edit update destroy mark_all_read]

  def mark_all_read
    comic = Comic.find(params[:id])
    series_lib = LibraryItem.find_or_create_by!(user: current_user, item: comic)
    consumed = ActiveModel::Type::Boolean.new.cast(params.fetch(:consumed, true))
    ActiveRecord::Base.transaction do
      comic.comic_issues.find_each do |issue|
        child_lib = LibraryItem.find_or_initialize_by(user: current_user, item: issue)
        attrs = { consumed: consumed, consumed_at: consumed ? child_lib.consumed_at || Date.current : nil }
        raise ActiveRecord::RecordInvalid, child_lib unless ConsumptionPasses.apply(current_user, issue, child_lib, attrs)
      end
      if consumed && comic.comic_issues.exists?
        series_lib.update!(consumed: true,
                           consumed_at: series_lib.consumed_at || Date.current)
      end
    end
    redirect_back fallback_location: comic, status: :see_other,
                  notice: "Issues marked as #{consumed ? 'read' : 'unread'}."
  end

  private

  def resource_params
    params.require(:comic).permit(
      :import_selection,
      :title, :issue_number, :publisher, :writer, :artist, :is_public, :thumbnail_url,
      :in_watchlist, :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id, :external_url,
      :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format
    )
  end
end
