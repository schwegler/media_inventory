# frozen_string_literal: true

class ReviewPagesController < ApplicationController
  def show
    # Recheck visibility on every request, including previously shared URLs.
    response.headers['Cache-Control'] = 'private, no-store'
    scope = LibraryItem.where(item_type: ReviewsController::REVIEWABLE_MODELS.keys)
    scope = if current_user
              scope.where(is_public: true).or(scope.where(user_id: current_user.id))
            else
              scope.where(is_public: true)
            end
    @entry = scope.includes(user: { avatar_attachment: :blob }).find_by(id: params[:id])
    return head :not_found unless @entry&.user && @entry.review.present? && @entry.item

    @item = @entry.item
    return head :not_found if @item.is_a?(TvEpisode) && !@item.tv_show
    return head :not_found if @item.is_a?(ComicIssue) && !@item.comic

    @entry.likes.load
  end
end
