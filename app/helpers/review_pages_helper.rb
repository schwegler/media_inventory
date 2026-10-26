# frozen_string_literal: true

module ReviewPagesHelper
  def canonical_review_url(entry)
    "#{public_trove_origin}#{public_review_path(entry)}"
  end

  def review_share_title(entry)
    "#{entry.user.name.presence || entry.user.display_handle}’s review of #{item_share_title(entry.item)}"
  end

  # Reviews have no spoiler flag. Keep all review prose out of unfurled previews;
  # game journal/milestone spoiler content is never part of this surface.
  def review_share_description(entry)
    rating = " Rated #{entry.rating} out of 5." if entry.rating.present?
    "Read this #{entry.item.class.model_name.human.downcase} review on Trove.#{rating}"
  end

  def review_artwork_item(item)
    return item.tv_show if item.is_a?(TvEpisode) && item.stored_cover_url.blank?
    return item.comic if item.is_a?(ComicIssue) && item.stored_cover_url.blank?

    item
  end
end
