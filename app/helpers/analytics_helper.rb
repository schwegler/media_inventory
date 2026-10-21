# frozen_string_literal: true

module AnalyticsHelper
  PUBLIC_ANALYTICS_PAGES = {
    %w[landing index] => { path: '/', title: 'Trove', type: 'home', group: 'public' },
    %w[shelves show] => { path: '/public_shelf', title: 'Public shelf', type: 'public_shelf', group: 'public' }
  }.freeze
  PUBLIC_ANALYTICS_CATALOGS = %w[movies tv_shows albums books comics video_games wrestling_events].freeze

  # Return fixed aggregate descriptors, never titles, handles, record IDs or URLs.
  def public_analytics_page
    return unless public_analytics_transport? && public_analytics_visitor?

    PUBLIC_ANALYTICS_PAGES[[controller_name, action_name]] || public_catalog_analytics_page
  end

  private

  def public_analytics_transport?
    Rails.env.production? && request.get? && request.format.html? && response.status == 200 &&
      request.host == 'trove.schweg.xyz' && request.ssl?
  end

  def public_analytics_visitor?
    !logged_in? && !hotwire_native_app? && request.query_parameters.empty? &&
      !request.user_agent.to_s.include?('MediaInventoryDesktop')
  end

  def public_catalog_analytics_page
    return unless PUBLIC_ANALYTICS_CATALOGS.include?(controller_name) && %w[index show].include?(action_name)

    { path: "/#{controller_name}/#{action_name}", title: "Trove #{controller_name.tr('_', ' ')}",
      type: 'catalog', group: controller_name }
  end
end
