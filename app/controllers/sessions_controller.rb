# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    email = params.dig(:session, :email) || params[:email]
    password = params.dig(:session, :password) || params[:password]
    email = email&.downcase

    user = User.find_by(email: email) if email.present?

    if user&.authenticate(password)
      reset_session
      log_in user
      flash[:success] = 'Logged in successfully.'
      redirect_to user
    else
      flash.now[:danger] = 'Invalid email/password combination.'
      render 'new', status: :unprocessable_content
    end
  end

  def bsky_create
    handle = params[:bsky_handle].to_s.strip
    password = params[:bsky_app_password].to_s.strip

    if handle.blank? || password.blank?
      flash[:danger] = 'Handle and App Password are required.'
      redirect_to login_url and return
    end

    session_data = BlueskyClient.new(handle, password).authenticate

    if session_data
      user = find_or_create_bsky_user(handle, password)
      reset_session
      log_in user
      flash[:success] = 'Successfully authenticated via Bluesky!'
      redirect_to user
    else
      flash[:danger] = 'Invalid Bluesky handle or app password.'
      redirect_to login_url
    end
  end

  def destroy
    log_out
    redirect_to root_url, status: :see_other
  end

  private

  def find_or_create_bsky_user(handle, password)
    user = User.find_by('LOWER(bsky_handle) = ?', handle.downcase)
    if user.nil?
      user = User.new(
        name: handle.split('.').first.titleize,
        bsky_handle: handle,
        password: SecureRandom.hex(16),
        confirmed_at: Time.current
      )
    end
    user.bsky_app_password = password

    # Fetch profile to get avatar_url
    client = BlueskyClient.new(handle, password)
    profile = client.get_profile(handle)
    user.avatar_url = profile['avatar'] if profile && profile['avatar'].present?

    user.save!
    user
  end
end
