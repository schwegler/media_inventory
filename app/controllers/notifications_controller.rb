# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :logged_in_user

  def index
    @notifications = current_user.notifications.order(created_at: :desc).limit(50)
  end

  def mark_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: 'Notifications marked as read.'
  end
end
