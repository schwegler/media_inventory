# frozen_string_literal: true

class MetadataRefreshesController < ApplicationController
  before_action :logged_in_user

  TYPES = { 'movies' => Movie, 'tv_shows' => TvShow, 'comics' => Comic,
            'albums' => Album, 'books' => Book, 'video_games' => VideoGame }.freeze

  def create
    klass = TYPES[params[:media_type]]
    return head :not_found unless klass

    item = klass.find(params[:media_id])
    return head :forbidden unless can_access?(item)

    state = MetadataRefresher.new(item, current_user).enqueue
    flash[:metadata_result] = state
    redirect_to polymorphic_path(item, anchor: 'metadata-health'), status: :see_other, notice: MetadataRefresh::MESSAGES.fetch(state)
  end
end
