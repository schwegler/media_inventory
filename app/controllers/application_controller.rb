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

  def can_access?(resource)
    return false if resource.nil?
    return true if global_resource?(resource)
    return can_access?(parent_resource(resource)) if activity_or_comment?(resource)

    # Ownership and Public Access checks
    return true if owner?(resource)
    return true if public_access?(resource)
    return true if anonymous_resource?(resource)

    false
  end

  def global_resource?(resource)
    %w[Movie TvShow TvEpisode Album Comic ComicIssue Book VideoGame WrestlingEvent]
      .include?(resource.class.name)
  end

  def activity_or_comment?(resource)
    resource.is_a?(Activity) || resource.is_a?(Comment)
  end

  def parent_resource(resource)
    resource.is_a?(Activity) ? resource.trackable : resource.commentable
  end

  def owner?(resource)
    resource.respond_to?(:user) && resource.user.present? && resource.user == current_user
  end

  def public_access?(resource)
    resource.respond_to?(:is_public) && resource.is_public
  end

  def anonymous_resource?(resource)
    resource.respond_to?(:user) && resource.user.nil?
  end
end
