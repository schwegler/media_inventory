# frozen_string_literal: true

class TvShowsController < InventoryController
  before_action :logged_in_user, only: %i[new create edit update destroy mark_season_watched]

  def new
    @tv_show = TvShow.new
  end

  def mark_season_watched
    @tv_show = TvShow.find(params[:id])
    season_number = params[:season].to_i
    episodes = @tv_show.tv_episodes.where(season: season_number)
    return redirect_back(fallback_location: @tv_show, alert: 'No episodes found for this season.') if episodes.empty?

    @library_item = LibraryItem.find_or_create_by!(user: current_user, item: @tv_show)
    consumed = params[:consumed].nil? || ActiveModel::Type::Boolean.new.cast(params[:consumed])

    ActiveRecord::Base.transaction do
      apply_season_episodes(episodes, consumed)
      check_series_completion if consumed
    end

    notice = "Season #{season_number} marked as #{consumed ? 'watched' : 'unwatched'}."
    redirect_back fallback_location: @tv_show, status: :see_other, notice: notice
  end

  private

  def apply_season_episodes(episodes, consumed)
    watched_date = consumed ? Time.current.to_date : nil
    episodes.find_each do |episode|
      ep_lib = LibraryItem.find_or_initialize_by(user: current_user, item: episode)
      attrs = if consumed
                { consumed: true, consumed_at: ep_lib.consumed_at || watched_date }
              else
                { consumed: false, consumed_at: nil }
              end
      ConsumptionPasses.apply(current_user, episode, ep_lib, attrs)
      SyncSeriesMetadataJob.perform_later(episode) if consumed && episode.thumbnail_url.blank?
    end
  end

  def check_series_completion
    total = @tv_show.tv_episodes.count
    return unless total.positive?

    watched = LibraryItem.where(user: current_user, item_type: 'TvEpisode',
                                item_id: @tv_show.tv_episodes.select(:id), consumed: true).count
    return unless watched == total && !@library_item.consumed?

    @library_item.update!(consumed: true, consumed_at: @library_item.consumed_at || Time.current.to_date)
  end

  def resource_params
    params.require(:tv_show).permit(
      :import_selection,
      :title, :network, :director, :writer, :actors, :genre, :release_year, :is_public, :thumbnail_url, :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :rating, :cover_image, :api_id, :external_url,
      :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format
    )
  end
end
