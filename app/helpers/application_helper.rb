# frozen_string_literal: true

module ApplicationHelper
  # Returns the full title on a per-page basis.
  def full_title(page_title = '')
    base_title = 'Trove'
    if page_title.blank?
      base_title
    else
      "#{page_title} | #{base_title}"
    end
  end

  def user_avatar_tag(user, size: 40)
    return nil if user.nil?

    if user.avatar_url.present?
      image_tag user.avatar_url, alt: user.name, class: 'user-avatar', width: size, height: size,
                                 style: "width: #{size}px !important; height: #{size}px !important; max-width: #{size}px !important; max-height: #{size}px !important; border-radius: 50% !important; object-fit: cover !important; border: 1px solid rgba(255, 255, 255, 0.1) !important; flex-shrink: 0 !important;"
    else
      initial = (user.name.presence || user.email.presence || '?')[0].upcase
      # Generate consistent color based on user name/id
      colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6']
      bg_color = colors[(user.id || 0) % colors.size]

      content_tag :div, initial, class: 'user-avatar-fallback',
                                 style: "width: #{size}px !important; height: #{size}px !important; max-width: #{size}px !important; max-height: #{size}px !important; border-radius: 50% !important; background: #{bg_color} !important; color: #fff !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; font-weight: bold !important; font-size: #{size * 0.4}px !important; text-shadow: 0 1px 2px rgba(0,0,0,0.2) !important; border: 1px solid rgba(255, 255, 255, 0.1) !important; flex-shrink: 0 !important;"
    end
  end

  def render_stars(rating)
    return '' if rating.blank?

    num = rating.to_f
    full_stars = num.floor
    half_star = num - full_stars >= 0.5 ? '½' : ''
    ('★' * full_stars) + half_star
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
