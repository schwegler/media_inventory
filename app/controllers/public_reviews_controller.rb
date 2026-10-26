# frozen_string_literal: true

class PublicReviewsController < ActionController::API
  include ItemSharingHelper
  include ReviewPagesHelper

  def index
    limit = params[:limit].to_s.match?(/\A[1-9]\d*\z/) ? [params[:limit].to_i, 20].min : 3
    payload = { reviews: PublicReviewFeed.new(limit: limit).records.map { |entry| serialize_review(entry) } }
    # Compute from the current visible representation before evaluating conditional headers.
    changed = stale?(etag: payload, public: true,
                     cache_control: { no_cache: true })
    render json: payload if changed
  end

  private

  def serialize_review(entry)
    item = entry.item
    {
      id: "library-item-#{entry.id}",
      body: PublicReviewFeed.plain_text(entry.review),
      rating: entry.rating.presence&.to_f,
      rating_scale: { min: 0, max: 5 },
      published_at: entry.review_published_at&.utc&.iso8601(6),
      updated_at: entry.updated_at.utc.iso8601(6),
      reviewer: { display_name: entry.user.name, profile_url: canonical_item_url(entry.user) },
      media_type: entry.item_type,
      item_title: item.is_a?(ComicIssue) ? item.display_title : item.title,
      item_url: canonical_item_url(item),
      review_url: canonical_review_url(entry),
      cover_url: item.stored_cover_url.present? ? "#{public_trove_origin}#{item.stored_cover_url}" : nil
    }
  end
end
