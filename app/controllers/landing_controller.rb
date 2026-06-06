# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    # Fetch all activities, ordered by newest first, with pagination (Kaminari)
    @activities = Activity.includes(:user, :trackable)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(15)
    @active_trackers = User.where.not(confirmed_at: nil).limit(5)
  end
end
