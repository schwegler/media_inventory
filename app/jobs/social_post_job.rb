# frozen_string_literal: true

class SocialPostJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  discard_on ActiveJob::DeserializationError

  def perform(record, activity_type)
    return unless %w[added reviewed].include?(activity_type)
    return if record.respond_to?(:is_public?) && !record.is_public?

    user = record.user
    return unless user

    %i[bsky mastodon].each do |platform|
      deliver(record, user, activity_type, platform)
    end
  end

  private

  def deliver(record, user, activity_type, platform)
    preference = activity_type == 'reviewed' ? 'post_reviews' : 'post_activity'
    return unless user.public_send("#{platform}_access_token").present?
    return unless user.public_send("#{platform}_#{preference}?")
    return if platform == :mastodon && user.mastodon_server.blank?

    message = record.send(:build_social_message, activity_type, platform)
    if platform == :bsky
      BlueskyClient.new(user).post(message, title: record.title.to_s)
    else
      MastodonClient.new(user).post(message)
    end
  rescue StandardError => e
    # Do not expose provider responses, which can contain credentials.
    Rails.logger.error "Social delivery failed for #{platform}: #{e.class}"
  end
end
