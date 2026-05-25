# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :logged_in_user, only: %i[index show destroy]
  before_action :admin_user,     only: :destroy

  def index
    @users = User.paginate(page: params[:page])
  end

  def show
    @user = User.find(params[:id])
  end

  def destroy
    User.delete(params[:id])
    flash[:success] = 'User deleted'
    redirect_to users_url
  end

  private

  # Confirms an admin user.
  def admin_user
    redirect_to(root_url) unless current_user.admin?
  end
end
