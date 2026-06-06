# frozen_string_literal: true

module ApplicationHelper
  # Returns the full title on a per-page basis.
  def full_title(page_title = '')
    base_title = 'SampleApp'
    if page_title.blank?
      base_title
    else
      "#{page_title} | #{base_title}"
    end
  end

  def community_stats_for(item)
    klass = item.class
    matching_items = klass.where('LOWER(title) = ?', item.title.to_s.strip.downcase).includes(:user)

    ratings = matching_items.map { |i| i.rating.to_f if i.rating.present? }.compact
    avg_rating = ratings.any? ? (ratings.sum.to_f / ratings.size).round(1) : nil

    watchers = matching_items.select { |i| i.in_watchlist? || i.consumed? }.map(&:user).uniq.compact
    collectors = matching_items.select(&:is_collected?).map(&:user).uniq.compact
    reviews = matching_items.select { |i| i.review.present? }

    {
      avg_rating: avg_rating,
      watchers: watchers,
      collectors: collectors,
      reviews: reviews
    }
  end
end
