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
    post_to_bluesky_if_enabled(activity_type)
  end

  def post_to_bluesky_if_enabled(activity_type)
    return unless bsky_configured?
    return unless should_post_to_bsky?(activity_type)

    msg = build_bsky_message(activity_type)
    Thread.new do
      client = BlueskyClient.new(user.bsky_handle, user.bsky_app_password)
      client.post(msg)
    end
  end

  def bsky_configured?
    respond_to?(:user) && user.present? && user.bsky_handle.present? && user.bsky_app_password.present?
  end

  def should_post_to_bsky?(activity_type)
    if activity_type == 'reviewed'
      user.bsky_post_reviews?
    else
      user.bsky_post_activity?
    end
  end

  def build_bsky_message(activity_type)
    is_review = (activity_type == 'reviewed')
    template = if is_review
                 user.bsky_message_review_template.presence || 'Reviewed [title]: [review] ([rating] stars)'
               else
                 user.bsky_message_activity_template.presence || 'Added [title] to my [type] list!'
               end

    interpolate_bsky_template(template, activity_type)
  end

  def interpolate_bsky_template(template, activity_type)
    msg = template.dup
    msg.gsub!('[title]', title.to_s) if msg.include?('[title]')
    msg.gsub!('[rating]', rating.to_s.presence || 'Unrated') if respond_to?(:rating) && msg.include?('[rating]')
    msg.gsub!('[review]', review.to_s.presence || '') if respond_to?(:review) && msg.include?('[review]')
    msg.gsub!('[type]', activity_type.to_s) if msg.include?('[type]')
    msg.strip
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
