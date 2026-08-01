# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :logged_in_user

  def index
    # Optimize to eager load notifiable items and actors with their avatars to prevent N+1 queries
    @notifications = current_user.notifications
                                 .includes(:notifiable, actor: { avatar_attachment: :blob })
                                 .order(created_at: :desc)
                                 .limit(50)
  end

  def mark_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: 'Notifications marked as read.'
  end
end
