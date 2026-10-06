# frozen_string_literal: true

class LandingController < ApplicationController
  include RecordPreloader

  def index
    if logged_in?
      @new_from_friends = preload_social_feed(fetch_friend_activities.to_a)
      @popular_items = fetch_popular_items
      @popular_reviews = preload_social_feed(fetch_popular_reviews.to_a)
    else
      @activities = public_activity_feed
      preload_social_feed(@activities.to_a)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  private

  def fetch_friend_activities
    activities = dashboard_activity_scope.where.not(user_id: current_user.id).limit(9)
    return activities if activities.size >= 3

    dashboard_activity_scope.limit(9)
  end

  def dashboard_activity_scope
    Activity.where(activity_type: %w[added consumed reviewed])
            .order(created_at: :desc)
  end

  def public_activity_feed
    Activity.order(created_at: :desc)
            .page(params[:page])
            .per(15)
  end

  def fetch_popular_items
    counts = Activity.group(:trackable_type, :trackable_id)
                     .order('count_all DESC').limit(9).count

    return fallback_popular_items if counts.empty?

    items = map_counts_to_items(counts)
    items.presence || fallback_popular_items
  end

  def map_counts_to_items(counts)
    ids_by_type = counts.keys.each_with_object({}) do |(type, id), hash|
      (hash[type] ||= []) << id if type && id
    end

    fetched = bulk_fetch_trackables(ids_by_type)
    counts.map { |(type, id), _| fetched.dig(type, id) }.compact
  end

  def bulk_fetch_trackables(ids_by_type)
    ids_by_type.each_with_object({}) do |(type, ids), hash|
      klass = type.constantize
      scope = klass.where(id: ids)
      scope = scope.includes(cover_image_attachment: :blob) if klass.reflect_on_association(:cover_image_attachment)
      hash[type] = scope.index_by(&:id)
    rescue NameError
      hash[type] = {}
    end
  end

  def fallback_popular_items
    items = LibraryItem.includes(:item).where(item_type: %w[Movie Album VideoGame],
                                              is_public: true).limit(6).map(&:item)
    preload_records_attachments(items).sample(6)
  end

  def fetch_popular_reviews
    # Filter non-blank reviews directly in SQL via INNER JOIN on library_items
    # to avoid loading 20 records into Ruby array memory and filtering downstream.
    # Omit :trackable from includes to prevent ActiveRecord::EagerLoadPolymorphicError;
    # associations are preloaded downstream via preload_social_feed.
    join_clause = 'INNER JOIN library_items ON activities.trackable_id = library_items.id ' \
                  "AND activities.trackable_type = 'LibraryItem'"

    Activity.joins(join_clause)
            .where(activity_type: 'reviewed')
            .where.not(library_items: { review: [nil, ''] })
            .order(activities: { created_at: :desc })
            .limit(3)
  end

  def db_status
    status = {
      database_connected: ActiveRecord::Base.connection.active?,
      activities_count: Activity.count,
      users_count: User.count,
      database_url: ENV['DATABASE_URL']&.gsub(%r{:[^@/]+@}, ':FILTERED@')
    }
    render json: status
  rescue StandardError => e
    render json: { database_connected: false, database_error: "#{e.class}: #{e.message}" }
  end
end
