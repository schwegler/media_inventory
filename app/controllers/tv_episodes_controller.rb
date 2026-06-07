# frozen_string_literal: true

class TvEpisodesController < ApplicationController
  before_action :logged_in_user

  def toggle_watched
    @tv_episode = TvEpisode.find(params[:id])

    if @tv_episode.tv_show.user != current_user
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    if @tv_episode.update(tv_episode_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @tv_episode.tv_show, notice: 'Episode updated.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to @tv_episode.tv_show, alert: 'Failed to update episode.' }
      end
    end
  end

  private

  def tv_episode_params
    params.require(:tv_episode).permit(:watched, :watched_at, :rating, :review)
  end
end
