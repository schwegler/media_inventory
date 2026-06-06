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

  def destroy
    log_out
    redirect_to root_url, status: :see_other
  end
end
