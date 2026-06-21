# frozen_string_literal: true

class SessionsController < ApplicationController
  def new; end

  def create
    authenticate_via_email
  end

  def destroy
    log_out
    redirect_to root_url, status: :see_other
  end

  private



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
