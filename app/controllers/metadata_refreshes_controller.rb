# frozen_string_literal: true

class MetadataRefreshesController < ApplicationController
  before_action :logged_in_user
  before_action :load_authorized_item

  TYPES = { 'movies' => Movie, 'tv_shows' => TvShow, 'comics' => Comic,
            'albums' => Album, 'books' => Book, 'video_games' => VideoGame }.freeze

  def create
    state = MetadataRefresher.new(@item, current_user).enqueue
    flash[:metadata_result] = state
    redirect_to polymorphic_path(@item, anchor: 'metadata-health'), status: :see_other,
                                                                    notice: MetadataRefresh::MESSAGES.fetch(state)
  end

  def status
    response.headers['Cache-Control'] = 'private, no-store'
    refresh = MetadataRefresh.find_by(item: @item)
    render json: { state: refresh&.current_state || 'idle', message: refresh&.message,
                   request_id: refresh&.requested_at&.iso8601(6) }
  end

  private

  def load_authorized_item
    klass = TYPES[params[:media_type]]
    return head :not_found unless klass

    @item = klass.find(params[:media_id])
    head :forbidden unless can_access?(@item)
  end
end
