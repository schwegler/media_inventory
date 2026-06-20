# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper
  include RecordPreloader

  before_action :auto_login_native_app

  private

  def auto_login_native_app
    return if logged_in?

    return unless hotwire_native_app? || tauri_desktop_app?

    user_id = cookies.permanent.signed[:device_user_id]
    user = User.find_by(id: user_id) if user_id

    if user.nil?
      user = User.create!(
        name: 'Device User',
        password: SecureRandom.hex(16),
        confirmed_at: Time.current
      )
      cookies.permanent.signed[:device_user_id] = user.id
    end

    log_in(user)
  end

  def tauri_desktop_app?
    request.user_agent&.include?('MediaInventoryDesktop')
  end

  # Confirms a logged-in user.
  def logged_in_user
    return if logged_in?

    flash[:danger] = 'Please log in.'
    redirect_to login_url
  end

  def can_access?(resource)
    return false if resource.nil?

    # Global media types are always accessible
    return true if %w[Movie TvShow TvEpisode Album Comic VideoGame WrestlingEvent].include?(resource.class.name)

    # 1. Owner access
    return true if resource.respond_to?(:user) && resource.user.present? && resource.user == current_user

    # 2. Public access (explicitly marked)
    return true if resource.respond_to?(:is_public) && resource.is_public

    # 3. Fallback: if it has no owner, it's public (for seeds/global items)
    return true if resource.respond_to?(:user) && resource.user.nil?

    false
  end
end
