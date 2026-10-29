# frozen_string_literal: true

module AppearanceSettings
  extend ActiveSupport::Concern

  def appearance; end

  def update_appearance
    if @user.update(appearance_params)
      respond_to do |format|
        format.html { redirect_to settings_appearance_path, notice: 'Appearance preferences saved.' }
        format.json { render json: { preferences: helpers.ui_preferences } }
      end
    else
      respond_to do |format|
        format.html { render :appearance, status: :unprocessable_content }
        format.json { render json: { errors: @user.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  private

  def appearance_params
    params.require(:user).permit(:theme, :seasonal_theme, :accent_theme, :content_density, :media_layout, :reduce_effects,
                                 :profile_accent, :profile_header)
  end
end
