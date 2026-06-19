# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    if params.dig(:session, :bsky_handle).present?
      authenticate_via_bluesky
    else
      authenticate_via_email
    end
  end

  def destroy
    log_out
    redirect_to root_url, status: :see_other
  end

  private

  def authenticate_via_bluesky
    bsky_handle = params.dig(:session, :bsky_handle)
    bsky_password = params.dig(:session, :bsky_password)

    user = User.find_by(bsky_handle: bsky_handle)
    if user && (user.bsky_app_password == bsky_password || user.bsky_password == bsky_password)
      login_success(user, 'Logged in successfully via Bluesky App Password.')
    else
      login_failure('Invalid Bluesky Handle/App Password combination.')
    end
  end

  def authenticate_via_email
    email = (params.dig(:session, :email) || params[:email])&.downcase
    password = params.dig(:session, :password) || params[:password]

    user = User.find_by(email: email) if email.present?

    if user&.authenticate(password)
      login_success(user, 'Logged in successfully.')
    else
      login_failure('Invalid email/password combination.')
    end
  end

  def login_success(user, message)
    reset_session
    log_in user
    flash[:success] = message
    redirect_to user
  end

  def login_failure(message)
    flash.now[:danger] = message
    render 'new', status: :unprocessable_content
  end
end
