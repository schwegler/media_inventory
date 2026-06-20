# frozen_string_literal: true

class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true

  validates :user_id, uniqueness: { scope: %i[likeable_type likeable_id] }

  after_create_commit :process_notifications

  private

  def process_notifications
    return unless likeable.respond_to?(:user) && likeable.user_id != user_id

    Notification.create!(recipient: likeable.user, actor: user, notifiable: self, action: 'liked')
  end
end
