# frozen_string_literal: true

module AnalyticsHelper
  # Return fixed, aggregate public page descriptors. No usernames, search terms,
  # record titles, IDs, request URLs or viewer identifiers enter analytics.
  def public_analytics_page
    return unless Rails.env.production? && request.get? && request.format.html?
    return unless response.status == 200
    return unless request.host == 'trove.schweg.xyz' && request.ssl?
    return if logged_in? || hotwire_native_app?
    return if request.user_agent.to_s.include?('MediaInventoryDesktop')
    return if request.query_parameters.any?

    if controller_name == 'landing' && action_name == 'index'
      return { path: '/', title: 'Trove', type: 'home', group: 'public' }
    end
    if controller_name == 'shelves' && action_name == 'show'
      return { path: '/public_shelf', title: 'Public shelf', type: 'public_shelf', group: 'public' }
    end

    catalogs = %w[movies tv_shows albums books comics video_games wrestling_events]
    return unless catalogs.include?(controller_name) && %w[index show].include?(action_name)

    { path: "/#{controller_name}/#{action_name}", title: "Trove #{controller_name.tr('_', ' ')}",
      type: 'catalog', group: controller_name }
  end
end
