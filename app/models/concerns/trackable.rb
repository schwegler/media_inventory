# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Trackable
  extend ActiveSupport::Concern

  included do
    has_many :activities, as: :trackable, dependent: :destroy
    has_many :likes, as: :likeable, dependent: :destroy
    after_save :log_activities
  end

  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def log_activities # rubocop:disable Metrics/MethodLength
    return unless respond_to?(:user) && user.present?

    if saved_change_to_id?
      # New record was created
      create_activity('added') if respond_to?(:is_collected?) && is_collected?
      create_activity('watchlist') if respond_to?(:in_watchlist?) && in_watchlist?
      create_activity('consumed') if respond_to?(:consumed?) && consumed?
      create_activity('reviewed') if (respond_to?(:review) && review.present?) || (respond_to?(:rating) && rating.present?)
    else
      # Existing record was updated
      is_collected_changed = respond_to?(:saved_change_to_is_collected?) &&
                             saved_change_to_is_collected? &&
                             respond_to?(:is_collected?) &&
                             is_collected? &&
                             !saved_change_to_is_collected[0]
      create_activity('added') if is_collected_changed

      in_watchlist_changed = respond_to?(:saved_change_to_in_watchlist?) &&
                             saved_change_to_in_watchlist? &&
                             respond_to?(:in_watchlist?) &&
                             in_watchlist? &&
                             !saved_change_to_in_watchlist[0]
      create_activity('watchlist') if in_watchlist_changed

      consumed_changed = respond_to?(:saved_change_to_consumed?) &&
                         saved_change_to_consumed? &&
                         respond_to?(:consumed?) &&
                         consumed? &&
                         !saved_change_to_consumed[0]
      create_activity('consumed') if consumed_changed

      # For review/rating, if it was blank and is now present, log reviewed activity
      review_became_present = respond_to?(:review) &&
                              review.present? &&
                              respond_to?(:saved_change_to_review?) &&
                              saved_change_to_review? &&
                              review_previously_was_blank?

      rating_became_present = respond_to?(:rating) &&
                              rating.present? &&
                              respond_to?(:saved_change_to_rating?) &&
                              saved_change_to_rating? &&
                              rating_previously_was_blank?

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
    post_to_mastodon_if_enabled(activity_type)
  end

  def post_to_bluesky_if_enabled(activity_type)
    return unless bsky_configured?
    return unless should_post_to_bsky?(activity_type)

    msg = build_social_message(activity_type, :bsky)
    Thread.new do
      client = BlueskyClient.new(user)
      client.post(msg)
    end
  end

  def bsky_configured?
    respond_to?(:user) && user.present? && user.bsky_access_token.present?
  end

  def should_post_to_bsky?(activity_type)
    activity_type == 'reviewed' ? user.bsky_post_reviews? : user.bsky_post_activity?
  end

  def post_to_mastodon_if_enabled(activity_type)
    return unless mastodon_configured?
    return unless should_post_to_mastodon?(activity_type)

    msg = build_social_message(activity_type, :mastodon)
    Thread.new do
      client = MastodonClient.new(user)
      client.post(msg)
    end
  end

  def mastodon_configured?
    respond_to?(:user) && user.present? && user.mastodon_access_token.present? && user.mastodon_server.present?
  end

  def should_post_to_mastodon?(activity_type)
    activity_type == 'reviewed' ? user.mastodon_post_reviews? : user.mastodon_post_activity?
  end

  def build_social_message(activity_type, platform)
    is_review = (activity_type == 'reviewed')

    template = if platform == :bsky
                 bsky_template(is_review)
               else
                 mastodon_template(is_review)
               end

    interpolate_social_template(template, activity_type)
  end

  def bsky_template(is_review)
    if is_review
      user.bsky_message_review_template.presence || 'Reviewed [title]: [review] ([rating] stars)'
    else
      user.bsky_message_activity_template.presence || 'Added [title] to my [type] list!'
    end
  end

  def mastodon_template(is_review)
    if is_review
      user.mastodon_message_review_template.presence || 'Reviewed [title]: [review] ([rating] stars)'
    else
      user.mastodon_message_activity_template.presence || 'Added [title] to my [type] list!'
    end
  end

  def interpolate_social_template(template, activity_type)
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
# rubocop:enable Metrics/ModuleLength
