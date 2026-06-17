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
      @activities = Activity.includes(:user, trackable: { cover_image_attachment: :blob })
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(15)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  private

  def fetch_friend_activities
    # Bolt: Eager load cover images and users to avoid N+1 in dashboard
    friend_activities = Activity.includes(:user, trackable: { cover_image_attachment: :blob })
                                .where.not(user_id: current_user.id)
                                .where(activity_type: %w[added consumed reviewed])
                                .order(created_at: :desc)
                                .limit(6)
    if friend_activities.size < 3
      # Fallback to all activities if there aren't enough from other users
      friend_activities = Activity.includes(:user, trackable: { cover_image_attachment: :blob })
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

    # Bolt: Group IDs by type to fetch in bulk and avoid N+1 queries
    items_by_type = popular_trackable_counts.keys.each_with_object({}) do |(type, id), hash|
      next if type.nil? || id.nil?
      (hash[type] ||= []) << id
    end

    fetched_items = items_by_type.each_with_object({}) do |(type, ids), hash|
      klass = type.constantize
      # Eager load cover images for models that support it
      records = if klass.respond_to?(:with_attached_cover_image)
                  klass.with_attached_cover_image.where(id: ids)
                else
                  klass.where(id: ids)
                end
      records.each { |r| hash[[type, r.id]] = r }
    rescue NameError
      next
    end

    # Maintain the original order from popular_trackable_counts
    popular_items = popular_trackable_counts.keys.map { |key| fetched_items[key] }.compact

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
    # Bolt: Eager load cover images and users to avoid N+1 in dashboard
    reviewed_activities = Activity.includes(:user, trackable: { cover_image_attachment: :blob })
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
