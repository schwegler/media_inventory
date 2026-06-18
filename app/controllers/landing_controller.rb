# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    if logged_in?
      # Dashboard Queries
      @new_from_friends = preload_trackable_attachments(fetch_friend_activities)
      @popular_items = fetch_popular_items
      @popular_reviews = preload_trackable_attachments(fetch_popular_reviews)
    else
      # Fetch all activities, ordered by newest first, with pagination (Kaminari)
      @activities = preload_trackable_attachments(
        Activity.includes(:user, :trackable)
                .order(created_at: :desc)
                .page(params[:page])
                .per(15)
      )
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

    return fallback_popular_items if popular_trackable_counts.empty?

    # Group IDs by type for bulk fetching to avoid N+1 queries
    ids_by_type = popular_trackable_counts.keys.each_with_object({}) do |(type, id), hash|
      next if type.nil? || id.nil?

      (hash[type] ||= []) << id
    end

    fetched_items = bulk_fetch_trackables(ids_by_type)

    # Map back to original ordered list from the lookup hash
    popular_items = popular_trackable_counts.map do |(type, id), _|
      fetched_items.dig(type, id)
    end.compact

    popular_items.empty? ? fallback_popular_items : popular_items
  end

  def bulk_fetch_trackables(ids_by_type)
    ids_by_type.each_with_object({}) do |(type, ids), hash|
      klass = type.constantize
      # Eager load Active Storage attachments if the model supports it
      scope = klass.where(id: ids)
      scope = scope.includes(cover_image_attachment: :blob) if klass.reflect_on_association(:cover_image_attachment)
      hash[type] = scope.index_by(&:id)
    rescue NameError
      hash[type] = {}
    end
  end

  def fallback_popular_items
    # Fallback to recent public items if no activity exists
    # Eager load Active Storage attachments for fallback items
    (Movie.includes(cover_image_attachment: :blob).where(is_public: true).limit(2).to_a +
     Album.includes(cover_image_attachment: :blob).where(is_public: true).limit(2).to_a +
     VideoGame.includes(cover_image_attachment: :blob).where(is_public: true).limit(2).to_a).sample(6)
  end

  def fetch_popular_reviews
    reviewed_activities = Activity.includes(:user, :trackable)
                                  .where(activity_type: 'reviewed')
                                  .order(created_at: :desc)
                                  .limit(20)
    reviewed_activities.select { |a| a.trackable&.review.present? }.first(3)
  end

  def preload_trackable_attachments(activities)
    return activities if activities.empty?

    # Group trackables by type to check for cover_image_attachment association
    trackables = activities.map(&:trackable).compact
    trackables_by_type = trackables.group_by(&:class)

    trackables_by_type.each do |klass, records|
      if klass.reflect_on_association(:cover_image_attachment)
        ActiveRecord::Associations::Preloader.new(records: records, associations: { cover_image_attachment: :blob }).call
      end
    end

    activities
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
