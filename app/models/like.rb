# frozen_string_literal: true

class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true

  validates :user_id, uniqueness: { scope: %i[likeable_type likeable_id] }

  after_create_commit :process_notifications
  after_save :clear_user_likes_cache
  after_destroy :clear_user_likes_cache

  private

  # Clears the cached list of liked items on the associated user instance
  # to keep the in-memory cache synchronized with the database.
  def clear_user_likes_cache
    user&.clear_likes_cache if user.respond_to?(:clear_likes_cache)
  end

  def process_notifications
    return unless likeable.respond_to?(:user) && likeable.user_id != user_id

    Notification.create!(recipient: likeable.user, actor: user, notifiable: self, action: 'liked')
  end
end
