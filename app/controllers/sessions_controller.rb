# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    email = params.dig(:session, :email)&.downcase
    return render 'new' if email.blank?

    user = User.find_by(email: email)

    if user
      user.generate_login_token
      UserMailer.otp_email(user).deliver_now
      session[:login_email] = user.email
    else
      # Since we don't prompt for name on login, we'll use part of the email as the name to satisfy validations
      name = email.split('@').first.truncate(50)
      user = User.create!(email: email, name: name)
      user.generate_login_token
      UserMailer.otp_email(user).deliver_now

      session[:login_email] = user.email
      flash[:info] = 'Account created! Please confirm your email within 45 minutes by entering the OTP sent to you.'
    end
    redirect_to verify_otp_path
  end

  def verify_otp
    if request.get?
      @email = session[:login_email] || (logged_in? && current_user.email)
      redirect_to root_url if @email.blank?
      return
    end

    email = params[:email]
    token = params[:token]
    user = User.find_by(email: email)

    if user && user.login_token == token && user.login_token_sent_at && user.login_token_sent_at > 45.minutes.ago
      user.update(confirmed_at: Time.current, login_token: nil, login_token_sent_at: nil)
      reset_session
      log_in user
      session.delete(:login_email)
      flash[:success] = 'Email confirmed and logged in successfully.'
      redirect_to user
    else
      flash.now[:danger] = 'Invalid or expired OTP.'
      @email = email
      render 'verify_otp'
    end
  end

  def destroy
    log_out
    redirect_to root_url
  end
end
