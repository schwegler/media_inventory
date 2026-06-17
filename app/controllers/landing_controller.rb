# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    if logged_in?
      # Dashboard Queries
      @new_from_friends = fetch_friend_activities
      @popular_items = fetch_popular_items
      @popular_reviews = fetch_popular_reviews
    else
      # Fetch all activities, ordered by newest first, with pagination (Kaminari)
      @activities = Activity.includes(:user, :trackable)
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(15)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  private

  def fetch_friend_activities
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
    friend_activities
  end

  def fetch_popular_items
    popular_trackable_counts = Activity.group(:trackable_type, :trackable_id)
                                       .order('count_all DESC')
                                       .limit(6)
                                       .count
    popular_items = popular_trackable_counts.map do |(type, id), _|
      next if type.nil? || id.nil?

      begin
        type.constantize.find_by(id: id)
      rescue NameError
        nil
      end
    end.compact

    if popular_items.empty?
      # Fallback to recent public items if no activity exists
      (Movie.where(is_public: true).limit(2).to_a +
                        Album.where(is_public: true).limit(2).to_a +
                        VideoGame.where(is_public: true).limit(2).to_a).sample(6)
    else
      popular_items
    end
  end

  def fetch_popular_reviews
    reviewed_activities = Activity.includes(:user, :trackable)
                                  .where(activity_type: 'reviewed')
                                  .order(created_at: :desc)
                                  .limit(20)
    reviewed_activities.select { |a| a.trackable&.review.present? }.first(3)
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
