# frozen_string_literal: true

module AppearanceSettings
  extend ActiveSupport::Concern

  def appearance; end

  def update_appearance
    if @user.update(appearance_params)
      redirect_to settings_appearance_path, notice: 'Appearance preferences saved.'
    else
      render :appearance, status: :unprocessable_content
    end
  end

  private

  def appearance_params
    params.require(:user).permit(:theme, :accent_theme, :content_density, :media_layout, :reduce_effects,
                                 :profile_accent, :profile_header)
  end
end
