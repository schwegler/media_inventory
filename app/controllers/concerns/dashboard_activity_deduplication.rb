# frozen_string_literal: true

module DashboardActivityDeduplication
  extend ActiveSupport::Concern

  private

  # Collapse lifecycle events before limiting so repeats don't crowd out discoveries.
  def unique_dashboard_activities(scope, limit:, reviews_only: false)
    activities = DashboardActivityQuery.new(scope, viewer_id: current_user&.id)
                                       .latest(limit: limit, reviews_only: reviews_only).to_a
    preload_social_feed(activities)
    DashboardActivityQuery.attach_review_entries(activities, viewer_id: current_user&.id)
    preload_social_feed(activities)
  end

  def dashboard_media(trackable)
    trackable.is_a?(LibraryItem) ? trackable.item : trackable
  end
end
