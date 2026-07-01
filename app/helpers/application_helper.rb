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

  def user_avatar_tag(user, size: 40) # rubocop:disable Metrics/MethodLength
    return nil if user.nil?

    if user.avatar.attached? || user.avatar_url.present?
      avatar_style = [
        "width: #{size}px !important;",
        "height: #{size}px !important;",
        "max-width: #{size}px !important;",
        "max-height: #{size}px !important;",
        'border-radius: 50% !important;',
        'object-fit: cover !important;',
        'border: 1px solid rgba(255, 255, 255, 0.1) !important;',
        'flex-shrink: 0 !important;'
      ].join(' ')
      source = user.avatar.attached? ? user.avatar : user.avatar_url
      image_tag source, alt: user.name, class: 'user-avatar', width: size, height: size,
                        style: avatar_style
    else
      initial = (user.name.presence || user.email.presence || '?')[0].upcase
      # Generate consistent color based on user name/id
      colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6']
      bg_color = colors[(user.id || 0) % colors.size]

      fallback_style = [
        "width: #{size}px !important;",
        "height: #{size}px !important;",
        "max-width: #{size}px !important;",
        "max-height: #{size}px !important;",
        'border-radius: 50% !important;',
        "background: #{bg_color} !important;",
        'color: #fff !important;',
        'display: inline-flex !important;',
        'align-items: center !important;',
        'justify-content: center !important;',
        'font-weight: bold !important;',
        "font-size: #{size * 0.4}px !important;",
        'text-shadow: 0 1px 2px rgba(0,0,0,0.2) !important;',
        'border: 1px solid rgba(255, 255, 255, 0.1) !important;',
        'flex-shrink: 0 !important;'
      ].join(' ')

      content_tag :div, initial, class: 'user-avatar-fallback',
                                 style: fallback_style
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
      query.where('is_public = ? OR user_id = ?', true, current_user.id).includes(:user)
    else
      query.where(is_public: true).includes(:user)
    end
  end

  # Overrides Rails default image_tag to automatically add the alt-text controller
  # when an alt attribute is provided.
  def image_tag(source, options = {})
    if options[:alt].present? && options[:alt].to_s.downcase != 'cover'
      options[:data] ||= {}

      # Extract existing controller string (or empty)
      existing_controllers = options[:data][:controller].to_s.split

      # Add alt-text if it's not already there
      unless existing_controllers.include?('alt-text')
        existing_controllers << 'alt-text'
        options[:data][:controller] = existing_controllers.join(' ')
      end
    end
    super
  end
end
