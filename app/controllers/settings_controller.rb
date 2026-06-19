# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :logged_in_user
  before_action :set_user

  def basic_info; end

  def notifications; end

  def account; end

  def import; end

  def import_letterboxd
    if params[:export_file].present?
      file = params[:export_file]
      temp_path = Rails.root.join('tmp', "letterboxd_export_#{current_user.id}_#{Time.now.to_i}.zip").to_s
      File.binwrite(temp_path, file.read)
      LetterboxdImportJob.perform_later(current_user.id, temp_path)
      flash[:success] = 'Import started. Your data will appear in your library soon.'
    else
      flash[:alert] = 'Please provide a file.'
    end
    redirect_to settings_import_path
  end

  def update_basic_info
    if @user.update(basic_info_params)
      flash[:success] = 'Basic information updated'
      redirect_to settings_basic_info_path
    else
      render 'basic_info', status: :unprocessable_content
    end
  end

  def update_notifications
    if @user.update(notification_params)
      flash[:success] = 'Notification preferences updated'
      redirect_to settings_notifications_path
    else
      render 'notifications', status: :unprocessable_content
    end
  end

  def update_account
    if @user.update(account_params)
      flash[:success] = 'Account settings updated'
      redirect_to settings_account_path
    else
      render 'account', status: :unprocessable_content
    end
  end

  def delete_account
    @user.destroy
    reset_session
    flash[:success] = 'Your account has been deleted'
    redirect_to root_url, status: :see_other
  end

  private

  def set_user
    @user = current_user
  end

  def basic_info_params
    params.require(:user).permit(:username, :name, :birthday, :bio, :avatar, :header_banner)
  end

  def notification_params
    params.require(:user).permit(
      :notify_email_likes, :notify_push_likes,
      :notify_email_follows, :notify_push_follows,
      :notify_email_comments, :notify_push_comments,
      :notify_email_posts, :notify_push_posts
    )
  end

  def account_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
