# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    if logged_in?
      # Dashboard Queries
      @new_from_friends = fetch_friend_activities
      @popular_items = fetch_popular_items
      @popular_reviews = fetch_popular_reviews
    else
      # Bolt: Fetch all activities, eager loading associations to avoid N+1 queries
      @activities = Activity.includes(:user, :trackable)
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(15)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  private

  def fetch_friend_activities
    # Bolt: Eager load basic associations to avoid N+1 in dashboard
    # We avoid nested attachment includes here to prevent polymorphic association errors
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
    popular_counts = Activity.group(:trackable_type, :trackable_id)
                             .order('count_all DESC').limit(6).count

    return fallback_popular_items if popular_counts.empty?

    # Bolt: Fetch in bulk to avoid N+1 queries
    items_by_type = popular_counts.keys.each_with_object({}) do |(type, id), hash|
      next if type.nil? || id.nil?

      (hash[type] ||= []) << id
    end

    fetched_items = bulk_fetch_trackables(items_by_type)
    popular_counts.keys.map { |key| fetched_items[key] }.compact.presence || fallback_popular_items
  end

  def bulk_fetch_trackables(items_by_type)
    items_by_type.each_with_object({}) do |(type, ids), hash|
      klass = type.constantize
      # Bolt: Safely eager load cover images only for models that support them
      records = if klass.respond_to?(:with_attached_cover_image)
                  klass.with_attached_cover_image.where(id: ids)
                else
                  klass.where(id: ids)
                end
      records.each { |r| hash[[type, r.id]] = r }
    rescue NameError
      next
    end
  end

  def fallback_popular_items
    (Movie.where(is_public: true).limit(2).to_a +
     Album.where(is_public: true).limit(2).to_a +
     VideoGame.where(is_public: true).limit(2).to_a).sample(6)
  end

  def fetch_popular_reviews
    # Bolt: Eager load basic associations to avoid N+1 in dashboard
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
