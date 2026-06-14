# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    if logged_in?
      # Dashboard Queries
      # 1. New from Friends: latest activities (excluding current user's, or all if alone)
      friend_activities = Activity.includes(:user, :trackable)
                                  .where.not(user_id: current_user.id)
                                  .where(activity_type: %w[added consumed reviewed])
                                  .order(created_at: :desc)
                                  .limit(6)
      if friend_activities.size < 3
        # Fallback to all activities if there aren't enough from other users
        friend_activities = Activity.includes(:user, :trackable)
                                    .where(activity_type: %w[added consumed reviewed])
                                    .order(created_at: :desc)
                                    .limit(6)
      end
      @new_from_friends = friend_activities

      # 2. Popular with Friends: most active items across the community
      popular_trackable_counts = Activity.group(:trackable_type, :trackable_id)
                                         .order('count_all DESC')
                                         .limit(6)
                                         .count
      @popular_items = popular_trackable_counts.map do |(type, id), _|
        next if type.nil? || id.nil?

        begin
          type.constantize.find_by(id: id)
        rescue NameError
          nil
        end
      end.compact

      if @popular_items.empty?
        # Fallback to recent public items if no activity exists
        @popular_items = (Movie.where(is_public: true).limit(2).to_a +
                          Album.where(is_public: true).limit(2).to_a +
                          VideoGame.where(is_public: true).limit(2).to_a).sample(6)
      end

      # 3. Popular Reviews with Friends: recent activities of type 'reviewed' containing review text
      reviewed_activities = Activity.includes(:user, :trackable)
                                    .where(activity_type: 'reviewed')
                                    .order(created_at: :desc)
                                    .limit(20)
      @popular_reviews = reviewed_activities.select { |a| a.trackable&.review.present? }.first(3)
    else
      # Fetch all activities, ordered by newest first, with pagination (Kaminari)
      @activities = Activity.includes(:user, :trackable)
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(15)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  def db_status
    status = {
      database_connected: false,
      database_error: nil,
      activities_count: nil,
      users_count: nil,
      database_url: ENV['DATABASE_URL']&.gsub(%r{:[^@/]+@}, ':FILTERED@')
    }

    begin
      status[:database_connected] = ActiveRecord::Base.connection.active?
      status[:activities_count] = Activity.count
      status[:users_count] = User.count
    rescue StandardError => e
      status[:database_error] = "#{e.class}: #{e.message}"
    end

    render json: status
  end
end
