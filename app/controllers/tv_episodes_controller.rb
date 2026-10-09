# frozen_string_literal: true

class TvEpisodesController < ApplicationController
  before_action :logged_in_user, only: %i[toggle_watched]

  def show
    @tv_episode = TvEpisode.find(params[:id])
    return if redirect_to_canonical_url(@tv_episode)
    return unless logged_in?

    @library_item = LibraryItem.find_by(user: current_user, item: @tv_episode)
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def toggle_watched
    @tv_episode = TvEpisode.find(params[:id])

    unless LibraryItem.exists?(user: current_user, item: @tv_episode.tv_show)
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @tv_episode)

    if @library_item.update(tv_episode_params)
      # Opportunistically fetch missing episode thumbnails from TVMaze
      SyncSeriesMetadataJob.perform_later(@tv_episode) if @tv_episode.thumbnail_url.blank?

      respond_to do |format|
        if params[:back_to_episode]
          format.html { redirect_to @tv_episode, notice: 'Episode updated.' }
          format.turbo_stream { redirect_to @tv_episode, notice: 'Episode updated.' }
        elsif params[:in_progress]
          @tv_show = @tv_episode.tv_show
          @in_progress_item = InProgressTracker.item_for(current_user, @tv_show)
          format.turbo_stream { render 'in_progress/update_tv_show' }
          format.html { redirect_back fallback_location: @tv_show, notice: "Logged #{@tv_episode.name}." }
        else
          format.turbo_stream
          format.html { redirect_back fallback_location: @tv_episode.tv_show, notice: 'Episode updated.' }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: @tv_episode.tv_show, alert: 'Failed to update episode.' }
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  private

  def tv_episode_params
    params.require(:tv_episode).permit(:consumed, :consumed_at, :rating, :review, :is_public)
  end
end
