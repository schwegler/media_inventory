# frozen_string_literal: true

module ApplicationHelper
  # Returns the full title on a per-page basis.
  def full_title(page_title = '')
    base_title = 'Trove'
    if page_title.blank?
      base_title
    else
      safe_join([page_title, base_title], ' | ')
    end
  end

  def user_avatar_tag(user, size: 40)
    return nil if user.nil?

    initial = (user.name.presence || '?')[0].upcase
    style = "--avatar-size: #{size.to_i}px; --avatar-font-size: #{size.to_i * 0.4}px;"
    if user.avatar.attached? || user.avatar_url.present?
      image_tag(user.avatar.attached? ? user.avatar : user.avatar_url,
                data: { controller: 'avatar', action: 'error->avatar#fallback', avatar_initial_value: initial },
                alt: user.name, class: 'user-avatar', width: size, height: size, style: style)
    else
      content_tag :span, initial, class: 'user-avatar-fallback', style: style,
                                  role: 'img', aria: { label: user.name }
    end
  end

  def ui_preferences
    user = current_user if logged_in?
    { theme: user&.theme || 'os', accent: user&.accent_theme || 'violet',
      density: user&.content_density || 'comfortable', mediaLayout: user&.media_layout || 'covers',
      effects: user&.reduce_effects? ? 'reduced' : 'full' }
  end

  def render_stars(rating)
    return '' if rating.blank?

    num = rating.to_f
    full_stars = num.floor
    half_star = num - full_stars >= 0.5 ? '½' : ''
    ('★' * full_stars) + half_star
  end

  def community_stats_for(item)
    matching_items = fetch_matching_items(item)

    ratings = matching_items.map { |i| i.rating.to_f if i.rating.present? }.compact
    avg_rating = ratings.any? ? (ratings.sum.to_f / ratings.size).round(1) : nil

    {
      avg_rating: avg_rating,
      watchers: matching_items.select { |i| i.in_backlog? || i.consumed? }.map(&:user).uniq.compact,
      collectors: matching_items.select(&:is_collected?).map(&:user).uniq.compact,
      reviews: matching_items.select { |i| i.review.present? }
    }
  end

  private

  def fetch_matching_items(item)
    query = LibraryItem.where(item: item)
    if logged_in?
      # Optimize to eager load user avatars to prevent N+1 queries in the community/watchers/collectors lists
      query.where('is_public = ? OR user_id = ?', true, current_user.id).includes(user: { avatar_attachment: :blob })
    else
      # Optimize to eager load user avatars to prevent N+1 queries in the community/watchers/collectors lists
      query.where(is_public: true).includes(user: { avatar_attachment: :blob })
    end
  end
end
