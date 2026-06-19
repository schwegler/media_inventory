# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    email = params.dig(:session, :email) || params[:email]
    password = params.dig(:session, :password) || params[:password]
    bsky_handle = params.dig(:session, :bsky_handle)
    bsky_password = params.dig(:session, :bsky_password)

    if bsky_handle.present? && bsky_password.present?
      user = User.find_by(bsky_handle: bsky_handle)
      if user && user.bsky_password == bsky_password
        reset_session
        log_in user
        flash[:success] = 'Logged in successfully via Bluesky App Password.'
        redirect_to user
        return
      else
        flash.now[:danger] = 'Invalid Bluesky Handle/App Password combination.'
        render 'new', status: :unprocessable_content
        return
      end
    end

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

  def destroy
    log_out
    redirect_to root_url, status: :see_other
  end
end
