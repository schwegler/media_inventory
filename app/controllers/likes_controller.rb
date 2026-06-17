# frozen_string_literal: true

class LikesController < ApplicationController
  before_action :logged_in_user

  def toggle
    likeable = find_likeable
    return unless likeable

    liked = perform_toggle_like(likeable)
    likes_count = likeable.likes.count

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "like_button_#{likeable.class.name}_#{likeable.id}",
          partial: 'likes/like_button',
          locals: { item: likeable }
        )
      end
      format.json { render json: { liked: liked, likes_count: likes_count } }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def find_likeable
    likeable_type = params[:likeable_type].to_s.strip
    likeable_id = params[:likeable_id].to_s.strip

    allowed_types = %w[Movie TvShow Album Comic VideoGame]
    unless allowed_types.include?(likeable_type)
      render json: { error: 'Invalid likeable type' }, status: :bad_request
      return nil
    end

    likeable = likeable_type.constantize.find_by(id: likeable_id)
    unless likeable
      render json: { error: 'Likeable item not found' }, status: :not_found
      return nil
    end

    likeable
  end

  def perform_toggle_like(likeable)
    like = current_user.likes.find_by(likeable: likeable)
    if like
      like.destroy
      false
    else
      current_user.likes.create!(likeable: likeable)
      true
    end
  end
end
