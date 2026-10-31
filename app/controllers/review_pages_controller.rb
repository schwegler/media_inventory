# frozen_string_literal: true

class ReviewPagesController < ApplicationController
  def show
    # Recheck visibility on every request, including previously shared URLs.
    response.headers['Cache-Control'] = 'private, no-store'
    @entry = visible_scope.includes(user: { avatar_attachment: :blob }).find_by(id: params[:id])
    return head :not_found unless @entry&.user && @entry.review.present? && @entry.item

    @item = @entry.item
    return head :not_found if @item.is_a?(TvEpisode) && !@item.tv_show
    return head :not_found if @item.is_a?(ComicIssue) && !@item.comic

    return head :not_found if %w[AlbumTrack BookChapter].include?(@item.class.name) && !OrderedReviewChildren.parent(@item)

    prepare_related_reviews
    @entry.likes.load
  end

  private

  def visible_scope
    scope = LibraryItem.where(item_type: ReviewsController::REVIEWABLE_MODELS.keys)
    return scope.where(is_public: true) unless current_user

    scope.where(is_public: true).or(scope.where(user_id: current_user.id))
  end

  def prepare_related_reviews
    @parent = OrderedReviewChildren.parent(@item)
    if @parent
      @parent_review = OrderedReviewChildren.visible_reviews(@entry.user, current_user).find_by(item: @parent)
      prepare_sibling_reviews
    elsif @item.is_a?(Book)
      @edition_reviews = @item.book_editions.order(:id).filter_map do |edition|
        reviews = OrderedReviewChildren.reviews(edition, @entry.user, current_user)
        [edition, reviews] if reviews.any?
      end
    else
      @child_reviews = OrderedReviewChildren.reviews(@item, @entry.user, current_user)
    end
  end

  def prepare_sibling_reviews
    siblings = OrderedReviewChildren.reviews(@item, @entry.user, current_user)
    index = siblings.index { |entry| entry.id == @entry.id }
    return unless index

    @previous_review = siblings[index - 1] if index.positive?
    @next_review = siblings[index + 1]
  end
end
