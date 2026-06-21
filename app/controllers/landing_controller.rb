# frozen_string_literal: true

class LandingController < ApplicationController
  def index
    if logged_in?
      @new_from_friends = preload_activities_attachments(fetch_friend_activities)
      @popular_items = fetch_popular_items
      @popular_reviews = preload_activities_attachments(fetch_popular_reviews)
    else
      @activities = preload_activities_attachments(public_activity_feed)
      @active_trackers = User.where.not(confirmed_at: nil).limit(5)
    end
  end

  def test_bsky
    u = User.where.not(bsky_access_token: nil).first || User.first

    if u.nil?
      render plain: 'No users found'
      return
    end

    if u.bsky_access_token.blank?
      render plain: "No bsky_access_token found for user #{u.id} (#{u.bsky_handle})"
      return
    end

    client = BlueskyClient.new(u)
    begin
      client.post('Testing the new persistent key from production...')
      render plain: 'Post called successfully.'
    rescue StandardError => e
      render plain: "Error posting: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    end
  end

  private

  def fetch_friend_activities
    activities = dashboard_activity_scope.where.not(user_id: current_user.id).limit(9)
    return activities if activities.size >= 3

    dashboard_activity_scope.limit(9)
  end

  def dashboard_activity_scope
    Activity.includes(:user, :trackable)
            .where(activity_type: %w[added consumed reviewed])
            .order(created_at: :desc)
  end

  def public_activity_feed
    Activity.includes(:user, :trackable)
            .order(created_at: :desc)
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
    Activity.includes(:user, :trackable)
            .where(activity_type: 'reviewed')
            .order(created_at: :desc)
            .limit(20)
            .select { |a| a.trackable&.review.present? }.first(3)
  end

  def preload_activities_attachments(activities)
    preload_records_attachments(activities.map(&:trackable).compact)
    activities
  end

  def preload_records_attachments(records)
    records.group_by(&:class).each do |klass, grouped_records|
      next unless klass.reflect_on_association(:cover_image_attachment)

      ActiveRecord::Associations::Preloader.new(
        records: grouped_records,
        associations: { cover_image_attachment: :blob }
      ).call
    end
    records
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
