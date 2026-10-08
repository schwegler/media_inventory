# frozen_string_literal: true

module DashboardActivityDeduplication
  extend ActiveSupport::Concern

  private

  # Collapse lifecycle events before limiting so repeats don't crowd out discoveries.
  def unique_dashboard_activities(scope, limit:, reviews_only: false)
    seen = {}
    results = []
    offset = 0
    loop do
      batch = preload_social_feed(scope.limit(100).offset(offset).to_a)
      break if batch.empty?

      batch.each do |activity|
        media = dashboard_media(activity.trackable)
        next unless media
        next if reviews_only && (!activity.trackable.respond_to?(:review) || activity.trackable.review.blank?)

        key = [activity.user_id, media.class.name, media.id]
        next if seen[key]

        seen[key] = true
        results << activity
        return results if results.size == limit
      end
      offset += batch.size
    end
    results
  end

  def dashboard_media(trackable)
    trackable.is_a?(LibraryItem) ? trackable.item : trackable
  end
end
