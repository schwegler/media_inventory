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

  def db_status
    status = {
      database_connected: false,
      database_error: nil,
      pending_migrations: nil,
      activities_count: nil,
      users_count: nil
    }

    begin
      status[:database_connected] = ActiveRecord::Base.connection.active?
      status[:activities_count] = Activity.count
      status[:users_count] = User.count
      begin
        ActiveRecord::Migration.check_pending!
        status[:pending_migrations] = false
      rescue ActiveRecord::PendingMigrationError => e
        status[:pending_migrations] = true
        status[:database_error] = e.message
      end
    rescue StandardError => e
      status[:database_error] = "#{e.class}: #{e.message}"
    end

    render json: status
  end
end
