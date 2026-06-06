# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    # Fetch all activities, ordered by newest first, with pagination
    @activities = Activity.includes(:user, :trackable)
                          .order(created_at: :desc)
                          .paginate(page: params[:page], per_page: 15)
  end
end
