# frozen_string_literal: true

module Trackable
  extend ActiveSupport::Concern

  included do
    has_many :activities, as: :trackable, dependent: :destroy
    after_save :log_activities
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def log_activities
    return unless respond_to?(:user) && user.present?

    if saved_change_to_id?
      # New record was created
      create_activity('added') if is_collected?
      create_activity('watchlist') if in_watchlist?
      create_activity('consumed') if consumed?
      create_activity('reviewed') if review.present? || rating.present?
    else
      # Existing record was updated
      create_activity('added') if saved_change_to_is_collected? && is_collected? && !saved_change_to_is_collected[0]

      create_activity('watchlist') if saved_change_to_in_watchlist? && in_watchlist? && !saved_change_to_in_watchlist[0]

      create_activity('consumed') if saved_change_to_consumed? && consumed? && !saved_change_to_consumed[0]

      # For review/rating, if it was blank and is now present, log reviewed activity
      review_became_present = review.present? && saved_change_to_review? && review_previously_was_blank?
      rating_became_present = rating.present? && saved_change_to_rating? && rating_previously_was_blank?
      create_activity('reviewed') if review_became_present || rating_became_present
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def create_activity(activity_type)
    activities.create!(
      user: user,
      activity_type: activity_type
    )
  end

  def review_previously_was_blank?
    change = saved_change_to_review
    change.nil? || change[0].blank?
  end

  def rating_previously_was_blank?
    change = saved_change_to_rating
    change.nil? || change[0].blank?
  end
end
