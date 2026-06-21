# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true

  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :replies, class_name: 'Comment', foreign_key: :parent_id, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true

  after_create_commit :process_notifications

  private

  def process_notifications
    # Notify parent comment author if reply
    if parent.present? && parent.user_id != user_id
      Notification.create!(recipient: parent.user, actor: user, notifiable: self, action: 'replied')
    end

    # Notify commentable owner (e.g. post or library item)
    if commentable.respond_to?(:user) &&
       commentable.user_id != user_id &&
       (parent.nil? || parent.user_id != commentable.user_id)
      Notification.create!(recipient: commentable.user, actor: user, notifiable: self, action: 'commented')
    end

    # Parse mentions: @username
    mentioned_usernames = content.scan(/@([a-zA-Z0-9_]+)/).flatten.uniq
    mentioned_users = User.where(username: mentioned_usernames).where.not(id: user_id)
    mentioned_users.each do |mentioned_user|
      Notification.create!(recipient: mentioned_user, actor: user, notifiable: self, action: 'mentioned')
    end
  end
end
