# frozen_string_literal: true

module NotificationsHelper
  def notification_target_path(notification)
    return nil unless notification&.notifiable

    target = case notification.notifiable
             when Like
               likeable = notification.notifiable.likeable
               likeable.is_a?(Comment) ? likeable.commentable : likeable
             when Comment
               notification.notifiable.commentable
             when EditSuggestion
               notification.notifiable.suggestable
             end

    return nil unless target

    polymorphic_path(target)
  rescue StandardError
    nil
  end
end
