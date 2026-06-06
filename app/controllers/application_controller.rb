# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper

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
end
